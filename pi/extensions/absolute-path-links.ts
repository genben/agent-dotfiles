/**
 * absolute-path-links
 *
 * Purpose:
 * Make file references in assistant prose clickable in terminals that support
 * OSC 8 hyperlinks, especially when plain relative paths are not recognized as
 * local files by the terminal's click handling.
 *
 * What it does:
 * - detects relative file paths in assistant text blocks
 * - resolves them against the current working directory
 * - wraps existing paths in OSC 8 hyperlinks
 * - uses the absolute filesystem path as the hyperlink target for bare paths
 * - uses a vscode://file... target for paths that include :line or :line:column
 * - preserves the original relative path as the visible label
 *
 * How it works:
 * pi does not expose a built-in post-processor for normal assistant text, so
 * this extension monkey-patches AssistantMessageComponent.updateContent() at
 * load time. Before the message is rendered, it rewrites matching text blocks
 * to inject OSC 8 links for paths that actually exist on disk.
 * 
 * Author: Gennadiy Bezkorovayniy (with Codex)
 */
import fs from "node:fs";
import path from "node:path";

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { AssistantMessageComponent } from "@mariozechner/pi-coding-agent";

const PATCH_KEY = "__pi_absolute_path_osc8_patch__";
const OSC8_PREFIX = "\u001b]8;;";

const RELATIVE_PATH_RE = /(^|[^\w/])((?:\.\.?\/)?(?:[A-Za-z0-9._-]+\/)+[A-Za-z0-9._-]+(?::\d+(?::\d+)?)?)(?=$|[^\w/.:~-])/g;

type AssistantMessageLike = {
	content: Array<
		| { type: "text"; text: string }
		| { type: "thinking"; thinking: string }
		| { type: string; [key: string]: unknown }
	>;
	[key: string]: unknown;
};

type PatchState = {
	patched: boolean;
	originalUpdateContent?: (this: AssistantMessageComponent, message: AssistantMessageLike) => void;
};

function getPatchState(): PatchState {
	const globalWithPatch = globalThis as typeof globalThis & { [PATCH_KEY]?: PatchState };
	if (!globalWithPatch[PATCH_KEY]) {
		globalWithPatch[PATCH_KEY] = { patched: false };
	}
	return globalWithPatch[PATCH_KEY]!;
}

function splitPathSuffix(candidate: string): { barePath: string; suffix: string } {
	const match = candidate.match(/^(.*?)(:\d+(?::\d+)?)?$/);
	return {
		barePath: match?.[1] ?? candidate,
		suffix: match?.[2] ?? "",
	};
}

function isExistingRelativePath(candidate: string, cwd: string): { absolutePath: string; suffix: string } | undefined {
	if (
		candidate.startsWith("/") ||
		candidate.startsWith("http://") ||
		candidate.startsWith("https://") ||
		candidate.startsWith("file://") ||
		candidate.startsWith("vscode://") ||
		candidate.startsWith("cursor://")
	) {
		return undefined;
	}

	const { barePath, suffix } = splitPathSuffix(candidate);
	const absolutePath = path.resolve(cwd, barePath);
	if (!fs.existsSync(absolutePath)) {
		return undefined;
	}
	return { absolutePath, suffix };
}

function toVsCodeTarget(absolutePath: string, suffix: string): string {
	return `vscode://file${absolutePath}${suffix}`;
}

function osc8(target: string, label: string): string {
	return `${OSC8_PREFIX}${target}\u0007${label}\u001b]8;;\u0007`;
}

function rewriteRelativePathsToOsc8(text: string, cwd: string): string {
	if (!text || text.includes(OSC8_PREFIX)) {
		return text;
	}

	return text.replace(RELATIVE_PATH_RE, (fullMatch, prefix: string, candidate: string) => {
		const resolvedPath = isExistingRelativePath(candidate, cwd);
		if (!resolvedPath) {
			return fullMatch;
		}
		const target = resolvedPath.suffix
			? toVsCodeTarget(resolvedPath.absolutePath, resolvedPath.suffix)
			: resolvedPath.absolutePath;
		return `${prefix}${osc8(target, candidate)}`;
	});
}

function rewriteAssistantMessage(message: AssistantMessageLike, cwd: string): AssistantMessageLike {
	return {
		...message,
		content: message.content.map((block) => {
			if (block.type !== "text" || typeof block.text !== "string") {
				return block;
			}
			return {
				...block,
				text: rewriteRelativePathsToOsc8(block.text, cwd),
			};
		}),
	};
}

function patchAssistantMessageRendering() {
	const state = getPatchState();
	if (state.patched) {
		return;
	}

	state.originalUpdateContent = AssistantMessageComponent.prototype.updateContent as PatchState["originalUpdateContent"];
	AssistantMessageComponent.prototype.updateContent = function patchedUpdateContent(message: AssistantMessageLike) {
		const rewrittenMessage = rewriteAssistantMessage(message, process.cwd());
		return state.originalUpdateContent!.call(this, rewrittenMessage);
	};
	state.patched = true;
}

export default function absolutePathLinksExtension(pi: ExtensionAPI) {
	patchAssistantMessageRendering();

	pi.on("session_start", async (_event, ctx) => {
		ctx.ui.notify("absolute-path-links: relative assistant file paths will render as absolute OSC 8 hyperlinks when they exist on disk", "info");
	});
}
