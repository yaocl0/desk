pragma Singleton

import Quickshell
import Qt.labs.folderlistmodel

// 当前壁纸。路径存在 config.json 里，和 theme / layout 同一份事实来源，
// 所以 IPC 设置和手改文件两条路都能走通，也跟着热重载。
//
// 顺带持有 wallpaperDir 下的候选列表：选择器拿它当 model，定时轮换拿它挑下一张。
// 列表放这儿而不是各扫一遍，是为了「认哪些后缀」只有一个定义处。
//
// TODO: 分输出壁纸。现在是全部输出同一张。
Singleton {
    id: root

    readonly property string path: Config.wallpaper

    // Image.source 要 URL；配置里存的是裸路径
    readonly property url source: {
        const p = root.path;
        if (p === "")
            return "";
        return p.includes("://") ? p : `file://${p}`;
    }

    readonly property bool hasWallpaper: root.path !== ""

    // 候选列表对外的两个口子：选择器拿 files 当 model，
    // 轮换和张数统计拿 count。内部那个 id 出不了这个文件，
    // 不把它们挂到根上，外面读到的就是 undefined —— 既不报错也不显示。
    readonly property alias files: fileList
    readonly property alias count: fileList.count

    function set(p: string) {
        Config.setWallpaper(p);
    }

    // 按文件名顺序切到下一张，到底回绕。
    // 当前这张不在目录里（或还没设壁纸）时 _indexOf 给 -1，于是从第一张开始。
    function next() {
        if (fileList.count === 0)
            return;
        const i = (root._indexOf(root.path) + 1) % fileList.count;
        root.set(fileList.get(i, "filePath"));
    }

    function _indexOf(p: string): int {
        for (let i = 0; i < fileList.count; i++) {
            if (fileList.get(i, "filePath") === p)
                return i;
        }
        return -1;
    }

    FolderListModel {
        id: fileList

        folder: `file://${Config.wallpaperDir}`
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }
}
