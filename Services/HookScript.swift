import Foundation
import AppKit

/// Het kleine script dat agents (Claude Code, Codex, …) aanroepen om Nook iets te laten weten.
/// Het gebruikt alleen programma's die al op macOS staan (sh en perl). Is Nook niet actief, dan doet het niets.
enum HookScript {
    static let contents = """
    #!/bin/sh
    # Nook hook: stuurt een gebeurtenis van een agent naar Nook (lokaal, via een Unix-socket).
    SOCK="$HOME/Library/Application Support/Nook/hub.sock"
    AGENT="claude-code"
    WAIT="false"
    PAYLOAD=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --agent) AGENT="$2"; shift 2 ;;
        --wait) WAIT="true"; shift ;;
        *) PAYLOAD="$1"; shift ;;
      esac
    done
    [ -S "$SOCK" ] || exit 0
    if [ -z "$PAYLOAD" ]; then PAYLOAD=$(cat | tr -d '\\n'); fi
    [ -z "$PAYLOAD" ] && PAYLOAD='{}'
    printf '{"agent":"%s","wait":%s,"event":%s}\\n' "$AGENT" "$WAIT" "$PAYLOAD" | /usr/bin/perl -MIO::Socket::UNIX -e 'my $s = IO::Socket::UNIX->new(Peer => $ARGV[0]) or exit 0; my $m = <STDIN>; print $s $m; $s->flush; my $r = <$s>; print $r if defined $r;' "$SOCK"
    exit 0
    """

    @discardableResult
    static func install() throws -> URL {
        let url = NookPaths.hookScriptURL
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    /// Voorbeeldconfiguratie voor ~/.claude/settings.json. Nook past dat bestand nooit zelf aan.
    static func claudeCodeConfig() -> String {
        let script = NookPaths.hookScriptURL.path
        let plain = "\\\"\(script)\\\" --agent claude-code"
        let wait = "\\\"\(script)\\\" --agent claude-code --wait"
        func group(_ command: String, matcher: String? = nil, timeout: Int? = nil) -> String {
            let matcherPart = matcher.map { "\"matcher\": \"\($0)\", " } ?? ""
            let timeoutPart = timeout.map { ", \"timeout\": \($0)" } ?? ""
            return "{ \(matcherPart)\"hooks\": [{ \"type\": \"command\", \"command\": \"\(command)\"\(timeoutPart) }] }"
        }
        return """
        {
          "hooks": {
            "SessionStart": [\(group(plain))],
            "UserPromptSubmit": [\(group(plain))],
            "PreToolUse": [
              \(group(wait, matcher: "Bash", timeout: 100)),
              \(group(plain, matcher: "Edit|Write|MultiEdit|Read|Grep|Glob|WebFetch"))
            ],
            "PostToolUse": [\(group(plain))],
            "Notification": [\(group(plain))],
            "Stop": [\(group(plain))],
            "SessionEnd": [\(group(plain))]
          }
        }
        """
    }

    static func codexConfig() -> String {
        "notify = [\"\(NookPaths.hookScriptURL.path)\", \"--agent\", \"codex\"]"
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
