# Claude Code cross-session messaging protocol

This reference supports the `orchestrate-agents-in-cmux` skill's bundled sender.

How the `SendMessage` tool delivers a message to another Claude Code session on the same
machine. This is the local peer transport, not the cloud or Remote Control path.

Everything here comes from reading the shipped binary
`@anthropic-ai/claude-code/bin/claude.exe`, version 2.1.246 (build 2026-08-25, git
`1ba9d2211ae14e591bd1d60451c217c51f415e86`), on macOS. The relevant modules log under
`[uds-messaging]` (the receiving inbox) and `[uds-client]` (the sender). None of this is
public API. Expect it to change between releases. Verified on 2026-08-30.

## Transport

Unix domain socket, `SOCK_STREAM`, newline-delimited JSON. The sender opens a connection,
writes its lines, and half-closes. One connection carries one message.

The receiver buffers until it sees `\n`, parses each line as JSON, and destroys the
connection on a line that exceeds the size cap. Lines that fail to parse are skipped with a
warning unless the inbox requires authentication and none has arrived yet, which closes the
connection.

macOS quirk in the sender: after `write()` it waits 150 ms before calling `end()`. Other
platforms end immediately.

## Socket paths

Each session binds one socket:

```
$XDG_RUNTIME_DIR/cc-socks/<pid>.sock
```

`XDG_RUNTIME_DIR` is usually unset on macOS, so the path falls back to the system temp
directory and lands at `/tmp/cc-socks/<pid>.sock`. If that path would exceed the `sun_path`
length limit, the code uses `/tmp/cc-socks-<uid>/<pid>.sock` instead. Termux uses
`$PREFIX/tmp`.

The socket file is mode 0600 inside a 0700 directory. If the directory cannot be created or
fails the ownership and permission check, the session starts with messaging disabled and
prints "Cross-session messaging is off: its socket directory could not be set up". That
check runs once at startup and never retries.

When the intended path is already bound by another live session (sibling pid namespaces, for
example), the session binds `<pid>-<8 hex>.sock` next to it and reaps stale moved-aside
siblings on the next start.

## Session registry

Every session writes `~/.claude/sessions/<pid>.json`:

```json
{
  "pid": 20870,
  "sessionId": "fde7b157-af9e-46d6-8c28-f6642d4a131a",
  "cwd": "/Users/gennadiy/dev/miarec/miarecweb",
  "startedAt": 1788063771598,
  "procStart": "Sun Aug 30 04:22:51 2026",
  "version": "2.1.246",
  "peerProtocol": 1,
  "peerFeatures": ["notify_idle", "artifact_yield"],
  "kind": "interactive",
  "entrypoint": "cli",
  "pidDomain": "darwin",
  "messagingSocketPath": "/tmp/cc-socks/20870.sock",
  "name": "miarecweb-60",
  "nameSource": "derived",
  "status": "shell",
  "updatedAt": 1788075905444
}
```

`ListAgents` reads these files, so peer discovery still works when the socket failed to bind.
A record without `messagingSocketPath` is a session whose inbox never came up.

`status` is one of `busy`, `shell`, `idle`, `waiting`. `kind` is one of `interactive`, `bg`,
`daemon`, `daemon-worker`. Before listing a peer as reachable, the sender connects to its
socket and disconnects, and treats `EBUSY` as alive.

## Auth tokens and key files

At startup each session mints two random 16-byte tokens, `peerToken` and `childToken`, and
publishes only the first:

```
~/.claude/sessions/<pid>.<sha256 of socket path>.key      mode 0600
{"peerToken":"ad7747d2f9eeb541a8aa8e06aaf7e835","procStart":"Sun Aug 30 04:22:51 2026","pidDomain":"darwin"}
```

The suffix is `sha256` of `path.resolve()` applied to the constructed socket path, not
`realpath`. On macOS that means the hash covers `/tmp/cc-socks/20870.sock` and not
`/private/tmp/...`. Confirmed against a live key file.

`childToken` goes into the environment of child processes as
`CLAUDE_CODE_MESSAGING_TOKEN` and never reaches disk. The receiver accepts either token and
records which one arrived, tagging the sender `peer` or `child`. No sender path in the binary
reads `CLAUDE_CODE_MESSAGING_TOKEN` for outbound auth. The shipped client always reads the
target's key file instead.

A session also exports `CLAUDE_CODE_MESSAGING_SOCKET` with its own socket path, which is how
child processes learn their parent's inbox.

### The token is a property of the inbox

Whoever writes to inbox X authenticates with X's `peerToken`. Nothing travels with the
message, and the receiver never echoes back the token it was given. Direction alone decides
which token to use, which is why a reply looks up a different key file than the original
send.

To find the token for a target socket path:

1. Compute `sha256(path.resolve(socketPath))`.
2. Scan `~/.claude/sessions/` for files matching `<pid>.<that hash>.key`.
3. Read `peerToken` from the winner.

When several pids match the same hash, which happens after pid reuse, the sender ranks
candidates and prefers a live owner whose `procStart` matches the registry record.

## Handshake and framing

The sender writes both lines in a single `write()`:

```
{"type":"auth","token":"<32 hex chars>"}\n
{"msgV":1,"msg_id":"...","type":"user",...}\n
```

The auth line must come first. On a connection that already sent a non-auth line, a later
auth frame is ignored.

Enforcement is platform dependent. `authRequired` defaults to "is this Windows", so the
Windows inbox drops unauthenticated connections and refuses to run at all if it cannot
publish its key file. On macOS and Linux the inbox accepts frames without an auth line, since
the 0700 directory and 0600 socket already restrict who can connect. The token still gets
sent and validated whenever the key file is readable.

A separate 30-second timer closes any connection that has not delivered one complete line.
That is a silence deadline, not an auth deadline.

## User frames

What `SendMessage` actually puts on the wire:

```json
{
  "msgV": 1,
  "msg_id": "3f2a1c88-9d41-4e7a-b0c2-5a6e7d8f9012",
  "type": "user",
  "from": "uds:/tmp/cc-socks/38591.sock",
  "priority": "next",
  "message": {
    "role": "user",
    "content": "<cross-session-message from=\"uds:/tmp/cc-socks/38591.sock\" from-name=\"codex-callback-proof\">\nyour text\n</cross-session-message>"
  }
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `type` | yes | `user` or `control`. A frame without a string `type` is dropped. |
| `message.content` | yes | Non-empty string. Any other shape is dropped with a warning. |
| `msgV` | no | Protocol version stamp, currently `1`. |
| `msg_id` | no | UUID. The receiver quotes it back in delivery receipts. |
| `from` | no | The sender's own inbox address. Needed for replies and receipts. |
| `priority` | no | `now`, `next`, or `later`. Anything else becomes `next`. |
| `uuid` | no | Message uuid for the receiver's transcript. Generated if absent. |
| `session_id` | no | If present it must equal the receiver's session id, otherwise the frame is dropped. |
| `file_attachments` | no | Files staged in the shared transfer spool, verified by `sha256`. |

The receiver enqueues an accepted frame as a user-role turn with `isMeta: true` and
`skipSlashCommands: true`, at the requested priority. It drains on the next tool round.

### Addresses

An address is `uds:` followed by the socket path with every character outside
`A-Za-z0-9:_/.\-` percent-encoded over its UTF-8 bytes. The bridge transport uses the same
encoding under a `bridge:` scheme.

### Body wrapper

The `content` string is what the receiving model sees, so the sender wraps the text:

```
<cross-session-message from="uds:..." from-session="..." hop-chain="..." from-name="..." from-mode="...">
text
</cross-session-message>
```

Attribute order is fixed and every attribute is optional. The receiver parses the tag, then
re-serializes it and compares against the original string. A wrapper that does not round-trip
exactly is treated as plain text. `hop-chain` entries are truncated HMACs keyed by a
per-process random value, used to spot relay loops.

## Control frames

Same connection shape, `type: "control"` plus an `action`:

```json
{"msgV":1,"msg_id":"...","type":"control","action":"rename","name":"new-name","from":"uds:..."}
```

| Action | Purpose |
| --- | --- |
| `rename` | Change the peer's displayed session name. |
| `notify_when_idle` | Subscribe to a one-shot idle notice from the target. |
| `peer_idle_notice` | The notice itself, sent back to the subscriber. |
| `peer_message_status` | Delivery receipt. |
| `artifact_replies_yielded` | Artifact comment-reply handoff. |

`peer_message_status` carries `status` (`held`, `denied`, `expired`, `delivered`, `refused`,
`dropped`), `orig_msg_id`, a `reason`, and for drops `drop_reason` plus `dropped_msg_ids`.
The sender keeps up to 200 outstanding sends and matches receipts against them.

## Replies

Receipts and idle notices use the same client function as an ordinary send, so they carry an
auth line built the same way. The token is the reply target's `peerToken`, read from that
target's key file at reply time.

Replies get three extra checks:

- The reply address must use the `uds:` scheme and sit in the same socket directory as the
  replier's own inbox. Otherwise the receipt is skipped and logged.
- A reply that resolves to the replier's own socket is dropped as a self-target.
- The reply passes `expectPeerPid`, taken from the credential read off the inbound
  connection. On connect the sender reads the endpoint's pid and refuses to write if it does
  not match.

## Limits and guards

| Limit | Value |
| --- | --- |
| Line cap | 1,048,576 bytes, counting the auth line and terminator |
| First-line silence deadline | 30,000 ms |
| Connect and send timeout | 5,000 ms |
| Token bucket capacity | 30 messages |
| Refill rate | 0.5 per second |
| Duplicate suppression window | 30,000 ms on identical bodies from one sender |
| Max self hops | 10 |
| Max relay chain length | 28 |
| Tracked senders | 256 |
| Outstanding sends tracked | 200 |

Set `CLAUDE_CODE_HARBOR_KITE_PACING_OFF` to skip the sender-side pacer.

Before writing, the sender also refuses a non-local path, a target whose `lstat` shows a
symlink, and a path where the registry shows no live session listening. That last one raises
`NoLiveInboxError` with code `ENOINBOX`.

## Minimal sender

```js
const net = require("net"), fs = require("fs"), path = require("path"), crypto = require("crypto");

const targetPid = 20870;
const sock = `/tmp/cc-socks/${targetPid}.sock`;
const hash = crypto.createHash("sha256").update(path.resolve(sock)).digest("hex");
const { peerToken } = JSON.parse(
  fs.readFileSync(`${process.env.HOME}/.claude/sessions/${targetPid}.${hash}.key`, "utf8"));

const enc = p => "uds:" + p.replace(/[^A-Za-z0-9:_/.\\-]/gu, c =>
  [...Buffer.from(c)].map(b => "%" + b.toString(16).toUpperCase().padStart(2, "0")).join(""));
const from = enc(`/tmp/cc-socks/${process.pid}.sock`);   // omit if you cannot receive replies

const frame = {
  msgV: 1,
  msg_id: crypto.randomUUID(),
  type: "user",
  from,
  priority: "next",
  message: {
    role: "user",
    content: `<cross-session-message from="${from}" from-name="probe">\nping\n</cross-session-message>`,
  },
};

const c = net.connect(sock, () => {
  c.write(JSON.stringify({ type: "auth", token: peerToken }) + "\n" +
          JSON.stringify(frame) + "\n");
  setTimeout(() => c.end(), 150);
});
```

Sending this injects a real user turn into the target session. Point it at a throwaway
`claude -p` session before pointing it at working sessions.

## How to re-derive this

The binary is a bun single-file executable with the JavaScript bundle stored as plain text.
Grep for byte offsets and dump windows around them:

```bash
b=~/.nvm/versions/node/v22.23.2/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
grep -a -o -b 'cc-socks' "$b"
dd if="$b" bs=1 skip=<offset-40000> count=200000 2>/dev/null | LC_ALL=C tr -c '\11\12\15\40-\176' '\n'
```

Useful anchors: `cc-socks`, `messagingSocketPath`, `[uds-messaging]`, `[uds-client]`,
`peer_message_status`, `cross-session-message`, `ownUdsHopToken`. Each module ends with an
`export{a as Xyz,...}` map, so a minified local name can be traced across modules by grepping
for `as <alias>` (the export) and `<alias> as` (the import).

## Open questions

- Which component sends `childToken`. The receiver validates it, but no sender path in the
  binary reads `CLAUDE_CODE_MESSAGING_TOKEN`.
- What `bridge:` addresses do on the wire. They share the address encoding and appear in the
  same code paths, but the transport was not traced.
