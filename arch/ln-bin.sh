lnbin() {
	local source=$1
	local target=$2
	ln -sfn "$(pwd)/$source" ~/.local/bin/"$target"
}