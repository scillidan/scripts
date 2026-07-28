#!/bin/sh
# Crop images to multiple aspect-ratio & size variants
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > imgs_crops
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <img1> <img2> ...

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

error=0

for file in "$@"; do
	dir=$(dirname "$file")
	name=$(basename "$file" | sed 's/\.[^.]*$//')
	ext="${file##*.}"

	while IFS='|' read -r ar sizes _; do
		rw="${ar%:*}"
		rh="${ar#*:}"

		ow=$(magick "$file" -ping -format "%w" info: 2>/dev/null) || continue
		oh=$(magick "$file" -ping -format "%h" info: 2>/dev/null) || continue

		if [ $((ow * rh)) -gt $((oh * rw)) ]; then
			cw=$((oh * rw / rh))
			ch=$oh
		else
			cw=$ow
			ch=$((ow * rh / rw))
		fi

		tmp="$dir/.crop_$$_${rw}_${rh}.$ext"
		magick "$file" -gravity center -crop "${cw}x${ch}+0+0" +repage "$tmp" 2>/dev/null

		old_ifs=$IFS
		IFS=','
		for sz in $sizes; do
			[ -z "$sz" ] && continue
			dim=$(echo "$sz" | tr '*' 'x')
			out="$dir/_${dim}_$name.$ext"
			if ! magick "$tmp" -resize "${dim}!" "$out" 2>/dev/null; then
				echo "Error: Failed to create $out"
				error=1
			fi
		done
		IFS=$old_ifs

		rm -f "$tmp"
	done <<'SPECS'
1:1|240*240|公众号头像
54:23|900*383,1080*460|公众号封面
1:1|200*200|公众号小图
1:1|600*600|公众号二维码名片
18:5|1080*300|公众号内容引导图
6:7|1080*1260|视频号封面竖版
16:9|1080*608|视频号封面横版
9:16|810*1440|直播封面
1:1|144*144|小程序头像
5:4|520*416|小程序封面
40:37|1280*1184|朋友圈封面
3:1|600*200|超链接配图
4:3|1440*1080|朋友圈图片
SPECS
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
