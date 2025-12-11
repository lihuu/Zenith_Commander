import React, { useState, useEffect, useRef } from "react";
import {
  Folder,
  File,
  FileText,
  Image,
  Film,
  Music,
  Terminal,
  ChevronRight,
  HardDrive,
  Command,
  Search,
  X,
  MoreHorizontal,
  Settings,
  Eye,
  ArrowLeft,
  Copy,
  Clipboard,
  Database,
  Cloud,
  Laptop,
  Sparkles,
  Bot,
  Loader2,
  Plus,
  LayoutTemplate,
  ExternalLink,
  Grid,
  List as ListIcon,
  AlignJustify,
  Edit3,
  Regex,
  Hash,
  Calendar,
  RefreshCw,
  ArrowRight,
  ShieldAlert,
  Play,
  CheckCircle,
} from "lucide-react";

// --- Mock Data & Types ---
const FILE_TYPES = {
  FOLDER: "folder",
  CODE: "code",
  IMAGE: "image",
  TEXT: "text",
};

const MOCK_DRIVES = [
  {
    id: "mac-hd",
    name: "Macintosh HD",
    type: "system",
    icon: Laptop,
    capacity: "450GB / 1TB",
    used: 45,
  },
  {
    id: "ext-ssd",
    name: "Samsung T7",
    type: "external",
    icon: HardDrive,
    capacity: "1.2TB / 2TB",
    used: 60,
  },
  {
    id: "net-nas",
    name: "Synology NAS",
    type: "network",
    icon: Cloud,
    capacity: "8TB / 12TB",
    used: 75,
  },
];

const generateMockFiles = (count, seed, driveId = "mac-hd") => {
  if (seed.includes("root") || seed === "") {
    const folders = [
      "Applications",
      "Users",
      "Library",
      "System",
      "Projects",
      "Downloads",
    ];
    return folders.map((name, i) => ({
      id: `${driveId}-${name}-${i}`,
      name: name,
      type: FILE_TYPES.FOLDER,
      size: "--",
      date: "Today",
      icon: Folder,
    }));
  }
  return Array.from({ length: count }).map((_, i) => {
    const typeProb = Math.random();
    let type = FILE_TYPES.TEXT;
    if (typeProb > 0.7) type = FILE_TYPES.FOLDER;
    else if (typeProb > 0.3) type = FILE_TYPES.CODE;
    return {
      id: `${seed}-${i}`,
      name:
        type === FILE_TYPES.FOLDER
          ? `Folder_${i}`
          : `File_${i}.${type === "code" ? "swift" : "txt"}`,
      type: type,
      size: type === "folder" ? "--" : `${Math.floor(Math.random() * 500)} KB`,
      date: "Today",
      icon: type === FILE_TYPES.FOLDER ? Folder : FileText,
    };
  });
};

const createTab = (drive = MOCK_DRIVES[0], path = ["Users"]) => ({
  id: Date.now() + Math.random(),
  drive: drive,
  path: path,
  files: generateMockFiles(12, "root", drive.id),
  cursor: 0,
});

export default function RsyncPrototype() {
  const [activePane, setActivePane] = useState("left");
  const [mode, setMode] = useState("NORMAL");
  const [panes, setPanes] = useState({
    left: {
      activeTabIndex: 0,
      viewMode: "list",
      tabs: [createTab(MOCK_DRIVES[0], ["Users", "Dev"])],
    },
    right: {
      activeTabIndex: 0,
      viewMode: "list",
      tabs: [createTab(MOCK_DRIVES[1], ["Backups", "2024"])],
    },
  });
  const [driveCursor, setDriveCursor] = useState(0);
  const [selections, setSelections] = useState(new Set());
  const [inputBuffer, setInputBuffer] = useState("");
  const [lastMessage, setLastMessage] = useState(null);
  const [contextMenu, setContextMenu] = useState({
    visible: false,
    x: 0,
    y: 0,
    file: null,
    paneSide: null,
  });

  // --- Sync State ---
  const [syncModal, setSyncModal] = useState({
    visible: false,
    step: "config",
    dryRunResults: [],
    progress: 0,
  });

  // Helpers
  const getActiveTab = (side) => panes[side].tabs[panes[side].activeTabIndex];
  const currentTab = getActiveTab(activePane);
  const currentFiles = currentTab.files;
  const showToast = (msg) => {
    setLastMessage(msg);
    setTimeout(() => setLastMessage(null), 2000);
  };

  // --- Rsync Logic Mock ---
  const openSyncModal = () => {
    setSyncModal({
      visible: true,
      step: "config",
      dryRunResults: [],
      progress: 0,
    });
    setMode("SYNC");
  };

  const runDryRun = () => {
    setSyncModal((prev) => ({ ...prev, step: "scanning" }));
    // Simulate analyzing diff
    setTimeout(() => {
      const mockDiff = [
        { type: "add", path: "src/components/Button.swift", size: "12 KB" },
        { type: "add", path: "src/utils/Helper.swift", size: "4 KB" },
        { type: "update", path: "README.md", size: "2 KB" },
        { type: "delete", path: "old_config.json", size: "0 KB" },
        { type: "add", path: "assets/logo.png", size: "1.2 MB" },
      ];
      setSyncModal((prev) => ({
        ...prev,
        step: "review",
        dryRunResults: mockDiff,
      }));
    }, 1500);
  };

  const executeSync = () => {
    setSyncModal((prev) => ({ ...prev, step: "syncing" }));
    // Simulate progress
    let p = 0;
    const interval = setInterval(() => {
      p += 10;
      if (p >= 100) {
        clearInterval(interval);
        setSyncModal((prev) => ({ ...prev, step: "done", progress: 100 }));
        showToast("Sync Completed Successfully");
      } else {
        setSyncModal((prev) => ({ ...prev, progress: p }));
      }
    }, 300);
  };

  // --- Key Handling ---
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (syncModal.visible) {
        if (e.key === "Escape") {
          setSyncModal({ ...syncModal, visible: false });
          setMode("NORMAL");
        }
        return;
      }
      // ... (existing keys) ...
      if (["ArrowUp", "ArrowDown", "Tab", "Space", "/"].includes(e.key))
        e.preventDefault();

      switch (e.key) {
        case "Tab":
          setActivePane((prev) => (prev === "left" ? "right" : "left"));
          break;
        case "S": // Shift + s for Sync
          if (e.shiftKey) openSyncModal();
          break;
        case "v":
          if (mode === "NORMAL") {
            setMode("VISUAL");
          } else if (mode === "VISUAL") {
            setMode("NORMAL");
            setSelections(new Set());
          }
          break;
        case "j": // Simplified navigation for brevity
          setPanes((prev) => {
            const p = prev[activePane];
            const t = p.tabs[p.activeTabIndex];
            const newCursor = Math.min(t.cursor + 1, t.files.length - 1);
            // Deep clone simplistic update
            const newTabs = [...p.tabs];
            newTabs[p.activeTabIndex] = { ...t, cursor: newCursor };
            return { ...prev, [activePane]: { ...p, tabs: newTabs } };
          });
          break;
        case "k":
          setPanes((prev) => {
            const p = prev[activePane];
            const t = p.tabs[p.activeTabIndex];
            const newCursor = Math.max(t.cursor - 1, 0);
            const newTabs = [...p.tabs];
            newTabs[p.activeTabIndex] = { ...t, cursor: newCursor };
            return { ...prev, [activePane]: { ...p, tabs: newTabs } };
          });
          break;
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [mode, activePane, panes, syncModal]);

  // --- Components ---

  const SyncModal = () => {
    if (!syncModal.visible) return null;

    const sourceSide = activePane;
    const targetSide = activePane === "left" ? "right" : "left";
    const sourceTab = getActiveTab(sourceSide);
    const targetTab = getActiveTab(targetSide);

    const sourcePath = `/${sourceTab.drive.name}/${sourceTab.path.join("/")}/`;
    const targetPath = `/${targetTab.drive.name}/${targetTab.path.join("/")}/`;

    return (
      <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-[200] flex items-center justify-center animate-in fade-in duration-200">
        <div className="bg-[#1e1e1e] border border-gray-600 rounded-lg shadow-2xl w-[700px] flex flex-col overflow-hidden">
          {/* Header */}
          <div className="bg-[#252526] px-4 py-3 border-b border-gray-700 flex justify-between items-center">
            <div className="flex items-center gap-2 text-white font-semibold">
              <RefreshCw
                size={16}
                className={syncModal.step === "syncing" ? "animate-spin" : ""}
              />
              Directory Synchronization (Rsync)
            </div>
            <div className="text-xs px-2 py-1 bg-blue-900/50 text-blue-300 rounded border border-blue-800">
              Profile:{" "}
              <span className="font-bold text-white">Mirror Backup</span>
            </div>
          </div>

          {/* Path Visualizer */}
          <div className="flex items-center p-4 bg-[#1a1a1a] border-b border-gray-700">
            <div className="flex-1">
              <div className="text-[10px] text-gray-500 uppercase font-bold mb-1">
                Source (Active)
              </div>
              <div
                className="text-sm text-green-400 font-mono truncate"
                title={sourcePath}
              >
                {sourcePath}
              </div>
            </div>
            <div className="px-4 text-gray-500">
              <ArrowRight size={24} />
            </div>
            <div className="flex-1 text-right">
              <div className="text-[10px] text-gray-500 uppercase font-bold mb-1">
                Destination
              </div>
              <div
                className="text-sm text-blue-400 font-mono truncate"
                title={targetPath}
              >
                {targetPath}
              </div>
            </div>
          </div>

          {/* Main Content Area */}
          <div className="flex-1 min-h-[300px] max-h-[50vh] overflow-y-auto bg-[#151515] p-4">
            {syncModal.step === "config" && (
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-xs text-gray-400 block border-b border-gray-700 pb-1">
                      Mode
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-300 cursor-pointer hover:bg-white/5 p-1 rounded">
                      <input
                        type="radio"
                        name="mode"
                        defaultChecked
                        className="accent-blue-500"
                      />
                      <span>Mirror (Delete extraneous files)</span>
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-300 cursor-pointer hover:bg-white/5 p-1 rounded">
                      <input
                        type="radio"
                        name="mode"
                        className="accent-blue-500"
                      />
                      <span>Update (Skip newer files)</span>
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-300 cursor-pointer hover:bg-white/5 p-1 rounded">
                      <input
                        type="radio"
                        name="mode"
                        className="accent-blue-500"
                      />
                      <span>Copy All (Overwrite everything)</span>
                    </label>
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs text-gray-400 block border-b border-gray-700 pb-1">
                      Options
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-300">
                      <input
                        type="checkbox"
                        defaultChecked
                        className="rounded bg-gray-700"
                      />{" "}
                      Recursive (-r)
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-300">
                      <input
                        type="checkbox"
                        defaultChecked
                        className="rounded bg-gray-700"
                      />{" "}
                      Preserve times (-t)
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-300">
                      <input
                        type="checkbox"
                        defaultChecked
                        className="rounded bg-gray-700"
                      />{" "}
                      Compress (-z)
                    </label>
                    <label className="flex items-center gap-2 text-sm text-red-300">
                      <input type="checkbox" className="rounded bg-gray-700" />{" "}
                      Force Delete (--delete)
                    </label>
                  </div>
                </div>
                <div className="mt-4 p-3 bg-black/40 rounded border border-gray-700 font-mono text-xs text-gray-400">
                  <div className="text-gray-500 mb-1">
                    # Generated Command Preview:
                  </div>
                  <span className="text-yellow-500">rsync</span> -avz --progress
                  --delete{" "}
                  <span className="text-green-500">"{sourcePath}"</span>{" "}
                  <span className="text-blue-500">"{targetPath}"</span>
                </div>
              </div>
            )}

            {(syncModal.step === "scanning" ||
              syncModal.step === "syncing") && (
              <div className="h-full flex flex-col items-center justify-center space-y-4">
                <Loader2 size={48} className="animate-spin text-blue-500" />
                <div className="text-gray-300">
                  {syncModal.step === "scanning"
                    ? "Calculating differences..."
                    : "Synchronizing files..."}
                </div>
                {syncModal.step === "syncing" && (
                  <div className="w-64 h-2 bg-gray-700 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-blue-500 transition-all duration-300"
                      style={{ width: `${syncModal.progress}%` }}
                    ></div>
                  </div>
                )}
              </div>
            )}

            {(syncModal.step === "review" || syncModal.step === "done") && (
              <div className="space-y-2">
                {syncModal.step === "done" ? (
                  <div className="text-center py-8 text-green-400 flex flex-col items-center gap-3">
                    <CheckCircle size={48} />
                    <div className="text-lg">Synchronization Complete</div>
                    <div className="text-sm text-gray-500">
                      5 files transferred, 1.2 MB total
                    </div>
                  </div>
                ) : (
                  <table className="w-full text-xs text-left">
                    <thead className="text-gray-500 border-b border-gray-700">
                      <tr>
                        <th className="py-1">Change</th>
                        <th className="py-1">File Path</th>
                        <th className="py-1 text-right">Size</th>
                      </tr>
                    </thead>
                    <tbody>
                      {syncModal.dryRunResults.map((item, i) => (
                        <tr
                          key={i}
                          className="border-b border-gray-800/50 hover:bg-[#222]"
                        >
                          <td className="py-1.5 w-20">
                            <span
                              className={`px-1.5 py-0.5 rounded uppercase text-[9px] font-bold 
                                                        ${
                                                          item.type === "add"
                                                            ? "bg-green-900/50 text-green-400"
                                                            : item.type ===
                                                              "delete"
                                                            ? "bg-red-900/50 text-red-400"
                                                            : "bg-blue-900/50 text-blue-400"
                                                        }`}
                            >
                              {item.type}
                            </span>
                          </td>
                          <td className="py-1.5 text-gray-300 font-mono">
                            {item.path}
                          </td>
                          <td className="py-1.5 text-right text-gray-500">
                            {item.size}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            )}
          </div>

          {/* Footer Controls */}
          <div className="p-4 border-t border-gray-700 bg-[#252526] flex justify-between items-center">
            <div className="text-xs text-gray-500">
              {syncModal.step === "review" &&
                `${syncModal.dryRunResults.length} changes detected`}
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setSyncModal({ ...syncModal, visible: false });
                  setMode("NORMAL");
                }}
                className="px-4 py-2 text-xs font-medium text-gray-300 hover:text-white hover:bg-gray-700 rounded transition-colors"
              >
                {syncModal.step === "done" ? "Close" : "Cancel"}
              </button>

              {syncModal.step === "config" && (
                <button
                  onClick={runDryRun}
                  className="px-4 py-2 text-xs font-medium bg-[#3a3a3a] hover:bg-[#4a4a4a] text-white rounded border border-gray-600 flex items-center gap-2"
                >
                  <ShieldAlert size={14} className="text-yellow-500" /> Dry Run
                </button>
              )}

              {syncModal.step === "review" && (
                <button
                  onClick={() => setSyncModal({ ...syncModal, step: "config" })}
                  className="px-4 py-2 text-xs font-medium text-gray-300 hover:text-white"
                >
                  Back
                </button>
              )}

              {(syncModal.step === "config" || syncModal.step === "review") && (
                <button
                  onClick={executeSync}
                  className={`px-4 py-2 text-xs font-medium text-white rounded flex items-center gap-2 shadow-lg
                                    ${
                                      syncModal.step === "review"
                                        ? "bg-green-600 hover:bg-green-500"
                                        : "bg-blue-600 hover:bg-blue-500"
                                    }`}
                >
                  <Play size={14} fill="currentColor" />
                  {syncModal.step === "review"
                    ? "Confirm & Sync"
                    : "Start Sync"}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  };

  // --- Simplified Pane for Context ---
  const Pane = ({ side }) => (
    <div
      className={`flex-1 bg-[#1e1e1e] border-r border-black flex items-center justify-center text-gray-500 relative ${
        activePane === side ? "bg-[#1e1e1e]" : "bg-black/20"
      }`}
    >
      <div className="text-center p-8">
        <HardDrive size={32} className="mx-auto mb-2 opacity-50" />
        <div>{side.toUpperCase()} Pane</div>
        <div className="text-xs mt-2 opacity-50">Press Shift+S to Sync</div>
      </div>
    </div>
  );

  return (
    <div className="flex flex-col h-screen bg-[#1e1e1e] text-gray-200 font-sans overflow-hidden">
      <div className="h-8 bg-[#2d2d2d] border-b border-black"></div>
      <div className="flex-1 flex">
        <Pane side="left" />
        <Pane side="right" />
      </div>
      <SyncModal />
      {lastMessage && (
        <div className="absolute top-10 left-1/2 -translate-x-1/2 bg-black/80 px-4 py-2 rounded text-sm text-white">
          {lastMessage}
        </div>
      )}
    </div>
  );
}
