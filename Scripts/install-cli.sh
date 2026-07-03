#!/bin/sh
# Installs the `prettydoc` command-line helper.
#
# Tries /usr/local/bin first, then falls back to ~/.local/bin. The helper simply
# launches the Pretty Doc app with the given files, so tools like Claude Code and
# Cursor can run `prettydoc file.md`.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$SCRIPT_DIR/prettydoc"

if [ ! -f "$SRC" ]; then
	echo "error: cannot find prettydoc shim next to this script" >&2
	exit 1
fi

install_to() {
	target_dir="$1"
	mkdir -p "$target_dir" 2>/dev/null || return 1
	install -m 0755 "$SRC" "$target_dir/prettydoc" 2>/dev/null || return 1
	echo "$target_dir/prettydoc"
}

if DEST=$(install_to "/usr/local/bin"); then
	echo "Installed: $DEST"
elif DEST=$(install_to "$HOME/.local/bin"); then
	echo "Installed: $DEST"
	case ":$PATH:" in
		*":$HOME/.local/bin:"*) : ;;
		*)
			echo
			echo "Note: $HOME/.local/bin is not on your PATH. Add it with:"
			echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
			;;
	esac
else
	echo "Could not install automatically. Try:" >&2
	echo "  sudo install -m 0755 \"$SRC\" /usr/local/bin/prettydoc" >&2
	exit 1
fi

echo
echo "Try it:"
echo "  prettydoc README.md"
echo "  prettydoc plan.md#some-heading      # jump to a heading"
echo "  some-tool | prettydoc -             # stream stdin (follow mode)"
echo "  prettydoc --help                    # all options"
