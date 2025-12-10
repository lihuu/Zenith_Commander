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
  Save,
  Zap,
  Sliders,
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

const SYNC_PROFILES = [
  {
    id: "p1",
    name: "Mirror Backup",
    mode: "mirror",
    options: ["-r", "-t", "--delete"],
  },
  { id: "p2", name: "Safe Update", mode: "update", options: ["-r", "-u"] },
  { id: "p3", name: "Full Clone", mode: "copy_all", options: ["-a"] },
  { id: "custom", name: "Custom", mode: "custom", options: ["-r", "-t"] }, // Added Custom Profile
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

export default function RsyncPrototypeFile() {
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
    selectedProfile: SYNC_PROFILES[0],
  });
  const [autoSyncFolders, setAutoSyncFolders] = useState(new Map()); // Map<FileID, ProfileID>

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
      selectedProfile: SYNC_PROFILES[0],
    });
    setMode("SYNC");
  };

  const runDryRun = () => {
    setSyncModal((prev) => ({ ...prev, step: "scanning" }));
    setTimeout(() => {
      const mockDiff = [
        { type: "add", path: "src/components/Button.swift", size: "12 KB" },
        { type: "delete", path: "old_config.json", size: "0 KB" },
        { type: "add", path: "assets/logo.png", size: "1.2 MB" },
      ];
      setSyncModal((prev) => ({
        ...prev,
        step: "review",
        dryRunResults: mockDiff,
      }));
    }, 1000);
  };

  const executeSync = () => {
    setSyncModal((prev) => ({ ...prev, step: "syncing" }));
    let p = 0;
    const interval = setInterval(() => {
      p += 20;
      if (p >= 100) {
        clearInterval(interval);
        setSyncModal((prev) => ({ ...prev, step: "done", progress: 100 }));
        showToast("Sync Completed");
      } else {
        setSyncModal((prev) => ({ ...prev, progress: p }));
      }
    }, 200);
  };

  const toggleAutoSync = (file, profile) => {
    if (!file) return;
    setAutoSyncFolders((prev) => {
      const newMap = new Map(prev);
      if (newMap.has(file.id)) {
        newMap.delete(file.id);
        showToast(`Auto-Sync disabled for ${file.name}`);
      } else {
        newMap.set(file.id, profile);
        showToast(`Auto-Sync enabled: ${profile.name}`);
      }
      return newMap;
    });
    closeContextMenu();
  };

  // --- Custom Config Handlers ---
  const updateCustomOption = (option, isChecked) => {
    setSyncModal((prev) => {
      const currentOptions = prev.selectedProfile.options;
      let newOptions = [...currentOptions];
      if (isChecked) {
        if (!newOptions.includes(option)) newOptions.push(option);
      } else {
        newOptions = newOptions.filter((o) => o !== option);
      }
      return {
        ...prev,
        selectedProfile: { ...prev.selectedProfile, options: newOptions },
      };
    });
  };

  const updateCustomMode = (mode) => {
    setSyncModal((prev) => ({
      ...prev,
      selectedProfile: { ...prev.selectedProfile, mode: mode },
    }));
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
      if (contextMenu.visible && e.key === "Escape") {
        closeContextMenu();
        return;
      }
      if (["ArrowUp", "ArrowDown", "Tab", "Space", "/"].includes(e.key))
        e.preventDefault();

      switch (e.key) {
        case "Tab":
          setActivePane((prev) => (prev === "left" ? "right" : "left"));
          break;
        case "S":
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
        case "j":
          setPanes((prev) => {
            const p = prev[activePane];
            const t = p.tabs[p.activeTabIndex];
            const newCursor = Math.min(t.cursor + 1, t.files.length - 1);
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
  }, [mode, activePane, panes, syncModal, contextMenu]);

  // --- Components ---

  const ContextMenu = () => {
    if (!contextMenu.visible) return null;
    const { x, y, file } = contextMenu;
    const isAutoSync = file && autoSyncFolders.has(file.id);
    const targetPane = contextMenu.paneSide === "left" ? "right" : "left";
    const targetTab = getActiveTab(targetPane);
    const targetPath = `/${targetTab.drive.name}/${
      targetTab.path[targetTab.path.length - 1]
    }`;

    return (
      <div
        className="fixed z-[100] w-64 bg-[#252526] border border-gray-700 rounded-lg shadow-2xl py-1 text-sm text-gray-200 animate-in fade-in duration-75"
        style={{ top: y, left: x }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="px-3 py-1.5 text-xs text-gray-500 font-medium border-b border-gray-700 mb-1 truncate flex items-center justify-between">
          <span>{file ? file.name : "Current Directory"}</span>
          {file && (
            <span className="text-[10px] bg-gray-700 px-1 rounded">
              {file.type}
            </span>
          )}
        </div>
        <div
          className="hover:bg-blue-600 hover:text-white px-3 py-1.5 cursor-pointer flex items-center gap-2"
          onClick={() => {
            showToast("Opened");
            closeContextMenu();
          }}
        >
          <Eye size={14} /> Open
        </div>
        <div className="my-1 border-t border-gray-700"></div>
        <div className="px-3 py-1 text-[10px] text-gray-500 font-bold uppercase tracking-wider">
          Sync Operations
        </div>
        <div
          className="hover:bg-blue-600 hover:text-white px-3 py-1.5 cursor-pointer flex items-center gap-2"
          onClick={() => {
            closeContextMenu();
            openSyncModal();
          }}
        >
          <RefreshCw size={14} />
          <div className="flex flex-col">
            <span>
              Sync to {targetPane === "right" ? "Right" : "Left"} Pane...
            </span>
            <span className="text-[10px] opacity-60 font-mono">
              {targetPath}
            </span>
          </div>
        </div>
        {file && file.type === FILE_TYPES.FOLDER && (
          <div className="hover:bg-blue-600 hover:text-white px-3 py-1.5 cursor-pointer flex items-center gap-2 group relative">
            <Zap
              size={14}
              className={isAutoSync ? "text-yellow-400" : "text-gray-400"}
            />
            <span className="flex-1">Auto-Sync Rule</span>
            <ChevronRight size={12} />
            <div className="absolute left-full top-0 ml-1 w-48 bg-[#252526] border border-gray-700 rounded-lg shadow-xl py-1 hidden group-hover:block">
              {SYNC_PROFILES.filter((p) => p.id !== "custom").map((profile) => (
                <div
                  key={profile.id}
                  className="hover:bg-blue-600 hover:text-white px-3 py-2 cursor-pointer flex items-center gap-2"
                  onClick={() => toggleAutoSync(file, profile)}
                >
                  {isAutoSync &&
                  autoSyncFolders.get(file.id).id === profile.id ? (
                    <CheckCircle size={12} className="text-green-400" />
                  ) : (
                    <div className="w-3"></div>
                  )}
                  <div className="flex flex-col">
                    <span>{profile.name}</span>
                    <span className="text-[9px] opacity-50">
                      {profile.mode}
                    </span>
                  </div>
                </div>
              ))}
              {isAutoSync && (
                <div
                  className="border-t border-gray-700 mt-1 pt-1 hover:bg-red-900/50 hover:text-white px-3 py-2 cursor-pointer text-red-400 text-xs"
                  onClick={() => toggleAutoSync(file, null)}
                >
                  Disable Auto-Sync
                </div>
              )}
            </div>
          </div>
        )}
        <div className="my-1 border-t border-gray-700"></div>
        <div
          className="hover:bg-blue-600 hover:text-white px-3 py-1.5 cursor-pointer flex items-center gap-2 text-pink-400 hover:text-white"
          onClick={() => {
            closeContextMenu();
          }}
        >
          <Sparkles size={14} /> AI Insight
        </div>
      </div>
    );
  };

  const closeContextMenu = () =>
    setContextMenu({ ...contextMenu, visible: false });
  const handleContextMenu = (e, file, side) => {
    e.preventDefault();
    e.stopPropagation();
    setActivePane(side);
    setContextMenu({
      visible: true,
      x: e.clientX,
      y: e.clientY,
      file: file,
      paneSide: side,
    });
  };

  const FileRow = ({ file, isActive, isSelected, isPaneActive }) => {
    const Icon = file.icon;
    const isAutoSync = autoSyncFolders.has(file.id);
    const syncProfile = autoSyncFolders.get(file.id);
    return (
      <div
        className={`flex items-center px-3 py-1.5 text-[13px] border-b border-transparent cursor-default select-none 
        ${
          isActive
            ? isPaneActive
              ? "bg-[#3262a8] text-white"
              : "bg-[#3a3a3a] border-gray-600 text-gray-300"
            : "hover:bg-white/5 text-gray-300"
        }
        ${isSelected ? "bg-white/10" : ""}`}
        onContextMenu={(e) =>
          handleContextMenu(
            e,
            file,
            isPaneActive ? activePane : activePane === "left" ? "right" : "left"
          )
        }
      >
        <Icon
          size={15}
          className={`mr-2 ${
            file.type === "folder"
              ? isActive && isPaneActive
                ? "text-white"
                : "text-blue-400"
              : "text-gray-400"
          }`}
        />
        <div className="flex-1 truncate font-medium flex items-center gap-2">
          {file.name}
          {isAutoSync && (
            <span
              className="flex items-center gap-1 text-[9px] bg-blue-900/50 text-blue-200 px-1.5 rounded border border-blue-800"
              title={`Auto-Sync: ${syncProfile.name}`}
            >
              <RefreshCw size={8} className="animate-spin-slow" />{" "}
              {syncProfile.name}
            </span>
          )}
        </div>
        <div
          className={`text-right w-20 ${
            isActive && isPaneActive ? "text-blue-100" : "text-gray-500"
          }`}
        >
          {file.size}
        </div>
      </div>
    );
  };

  const Pane = ({ side }) => {
    const p = panes[side];
    const t = p.tabs[p.activeTabIndex];
    return (
      <div
        className={`flex-1 bg-[#1e1e1e] border-r border-black flex flex-col ${
          activePane === side ? "opacity-100" : "opacity-80"
        }`}
        onClick={() => setActivePane(side)}
        onContextMenu={(e) => handleContextMenu(e, null, side)}
      >
        <div className="h-8 bg-[#252526] border-b border-[#1e1e1e] flex items-center px-3 text-xs text-gray-500">
          <HardDrive size={12} className="mr-2" /> {t.drive.name}{" "}
          <ChevronRight size={10} className="mx-1" /> {t.path.join(" / ")}
        </div>
        <div className="flex-1 overflow-y-auto no-scrollbar pt-1">
          {t.files.map((f, i) => (
            <FileRow
              key={f.id}
              file={f}
              isActive={t.cursor === i}
              isPaneActive={activePane === side}
              isSelected={selections.has(f.id)}
            />
          ))}
        </div>
      </div>
    );
  };

  const SyncModalUI = () => {
    if (!syncModal.visible) return null;
    const isCustom = syncModal.selectedProfile.id === "custom";

    return (
      <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-[200] flex items-center justify-center animate-in fade-in duration-200">
        <div className="bg-[#1e1e1e] border border-gray-600 rounded-lg shadow-2xl w-[700px] flex flex-col">
          <div className="bg-[#252526] px-4 py-3 border-b border-gray-700 flex justify-between items-center text-white font-semibold">
            <div className="flex items-center gap-2">
              <RefreshCw size={16} /> Sync Cockpit
            </div>
            <div className="flex gap-2">
              {SYNC_PROFILES.map((p) => (
                <button
                  key={p.id}
                  onClick={() => {
                    // When switching to custom, preserve current settings if possible, or reset to defaults
                    if (p.id === "custom") {
                      setSyncModal((prev) => ({
                        ...prev,
                        selectedProfile: {
                          ...p,
                          options: prev.selectedProfile.options,
                          mode: prev.selectedProfile.mode,
                        },
                      }));
                    } else {
                      setSyncModal((prev) => ({ ...prev, selectedProfile: p }));
                    }
                  }}
                  className={`text-[10px] px-2 py-1 rounded border flex items-center gap-1 ${
                    syncModal.selectedProfile.id === p.id
                      ? "bg-blue-600 border-blue-500"
                      : "bg-[#333] border-gray-600 text-gray-400 hover:text-white"
                  }`}
                >
                  {p.id === "custom" && <Sliders size={10} />}
                  {p.name}
                </button>
              ))}
            </div>
          </div>
          <div className="p-6 bg-[#151515] min-h-[250px] text-gray-300 text-sm space-y-4">
            {syncModal.step === "config" ? (
              <>
                {isCustom ? (
                  // Custom Configuration View
                  <div className="grid grid-cols-2 gap-6 animate-in fade-in slide-in-from-top-2 duration-200">
                    <div className="space-y-3">
                      <label className="text-xs text-blue-400 font-bold uppercase tracking-wider block border-b border-blue-900/50 pb-1">
                        Sync Mode
                      </label>
                      <label className="flex items-center gap-3 p-2 rounded hover:bg-white/5 cursor-pointer">
                        <input
                          type="radio"
                          name="mode"
                          className="accent-blue-500"
                          checked={syncModal.selectedProfile.mode === "mirror"}
                          onChange={() => {
                            updateCustomMode("mirror");
                            updateCustomOption("--delete", true);
                          }}
                        />
                        <div className="flex flex-col">
                          <span className="text-white text-xs font-medium">
                            Mirror
                          </span>
                          <span className="text-[10px] text-gray-500">
                            Deletes extra files in destination
                          </span>
                        </div>
                      </label>
                      <label className="flex items-center gap-3 p-2 rounded hover:bg-white/5 cursor-pointer">
                        <input
                          type="radio"
                          name="mode"
                          className="accent-blue-500"
                          checked={syncModal.selectedProfile.mode === "update"}
                          onChange={() => {
                            updateCustomMode("update");
                            updateCustomOption("--delete", false);
                            updateCustomOption("-u", true);
                          }}
                        />
                        <div className="flex flex-col">
                          <span className="text-white text-xs font-medium">
                            Update
                          </span>
                          <span className="text-[10px] text-gray-500">
                            Skips newer files in destination
                          </span>
                        </div>
                      </label>
                      <label className="flex items-center gap-3 p-2 rounded hover:bg-white/5 cursor-pointer">
                        <input
                          type="radio"
                          name="mode"
                          className="accent-blue-500"
                          checked={
                            syncModal.selectedProfile.mode === "copy_all"
                          }
                          onChange={() => updateCustomMode("copy_all")}
                        />
                        <div className="flex flex-col">
                          <span className="text-white text-xs font-medium">
                            Copy All
                          </span>
                          <span className="text-[10px] text-gray-500">
                            Standard copy, no deletions
                          </span>
                        </div>
                      </label>
                    </div>
                    <div className="space-y-3">
                      <label className="text-xs text-blue-400 font-bold uppercase tracking-wider block border-b border-blue-900/50 pb-1">
                        Rsync Flags
                      </label>
                      {[
                        { flag: "-r", label: "Recursive" },
                        { flag: "-t", label: "Preserve Times" },
                        { flag: "-z", label: "Compress Data" },
                        { flag: "-u", label: "Update Only" },
                        { flag: "-a", label: "Archive Mode" },
                        {
                          flag: "--delete",
                          label: "Force Delete",
                          danger: true,
                        },
                      ].map((opt) => (
                        <label
                          key={opt.flag}
                          className={`flex items-center gap-2 text-xs ${
                            opt.danger ? "text-red-400" : "text-gray-300"
                          } hover:text-white cursor-pointer select-none`}
                        >
                          <input
                            type="checkbox"
                            className={`rounded bg-gray-700 border-gray-600 focus:ring-0 ${
                              opt.danger ? "text-red-500" : "text-blue-500"
                            }`}
                            checked={syncModal.selectedProfile.options.includes(
                              opt.flag
                            )}
                            onChange={(e) =>
                              updateCustomOption(opt.flag, e.target.checked)
                            }
                          />
                          <span className="font-mono bg-black/30 px-1 rounded text-[10px] opacity-70 w-12">
                            {opt.flag}
                          </span>
                          {opt.label}
                        </label>
                      ))}
                    </div>
                  </div>
                ) : (
                  // Standard Profile Summary
                  <div className="p-4 bg-blue-900/10 border border-blue-800/50 rounded-lg text-blue-200 flex items-start gap-4">
                    <ShieldAlert size={24} className="mt-1 text-blue-400" />
                    <div>
                      <div className="font-bold text-base text-blue-100">
                        {syncModal.selectedProfile.name}
                      </div>
                      <div className="text-xs opacity-70 mt-1 mb-2">
                        Optimized for:{" "}
                        {syncModal.selectedProfile.mode.toUpperCase()}
                      </div>
                      <div className="flex gap-2">
                        {syncModal.selectedProfile.options.map((opt) => (
                          <span
                            key={opt}
                            className="px-1.5 py-0.5 bg-blue-950 border border-blue-800 rounded text-[10px] font-mono text-blue-300"
                          >
                            {opt}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>
                )}

                {/* Command Preview */}
                <div className="text-xs text-gray-500 font-mono mt-2 pt-4 border-t border-white/5">
                  <div className="mb-1 text-[10px] uppercase tracking-wide opacity-50">
                    Generated Command
                  </div>
                  <div className="p-2 bg-black/50 rounded border border-white/5 text-gray-300 break-all">
                    <span className="text-yellow-500">rsync</span> -v{" "}
                    {syncModal.selectedProfile.options.join(" ")}{" "}
                    <span className="text-green-500">/Source/</span>{" "}
                    <span className="text-blue-500">/Dest/</span>
                  </div>
                </div>
              </>
            ) : (
              <div className="flex flex-col items-center justify-center h-full gap-4 pt-8">
                {syncModal.step === "done" ? (
                  <CheckCircle size={48} className="text-green-500" />
                ) : (
                  <Loader2 size={48} className="animate-spin text-blue-500" />
                )}
                <div>
                  {syncModal.step === "done" ? "Success" : "Processing..."}
                </div>
              </div>
            )}
          </div>
          <div className="p-4 border-t border-gray-700 bg-[#252526] flex justify-end gap-3">
            <button
              onClick={() => setSyncModal({ ...syncModal, visible: false })}
              className="px-4 py-2 text-xs text-gray-300 hover:text-white"
            >
              Cancel
            </button>
            {syncModal.step === "config" && (
              <button
                onClick={runDryRun}
                className="px-4 py-2 text-xs bg-[#333] text-white border border-gray-600 rounded hover:bg-[#444]"
              >
                Dry Run
              </button>
            )}
            <button
              onClick={executeSync}
              className="px-4 py-2 text-xs bg-blue-600 text-white rounded hover:bg-blue-500"
            >
              {syncModal.step === "done" ? "Close" : "Execute"}
            </button>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="flex flex-col h-screen bg-[#1e1e1e] text-gray-200 font-sans overflow-hidden">
      <div className="h-8 bg-[#2d2d2d] border-b border-black"></div>
      <div className="flex-1 flex">
        <Pane side="left" />
        <Pane side="right" />
      </div>
      <SyncModalUI />
      <ContextMenu />
      {lastMessage && (
        <div className="absolute top-10 left-1/2 -translate-x-1/2 bg-black/80 px-4 py-2 rounded text-sm text-white border border-white/10 shadow-lg z-[300]">
          {lastMessage}
        </div>
      )}
    </div>
  );
}
