// src/components/Tabs.tsx (或者 .jsx 如果您不使用 TypeScript)

import React, { useState } from "react";
import { Settings, User, Bell } from "lucide-react"; // 导入 Lucide 图标

const Tabs = () => {
  // 定义 Tab 数据
  const tabs = [
    {
      id: "profile",
      label: "个人资料",
      icon: User,
      content: (
        <div className="p-6">
          <h2 className="text-xl font-semibold mb-3">个人资料设置</h2>
          <p className="text-gray-700">
            在这里管理您的个人信息，例如姓名、电子邮件和头像。
          </p>
          <button className="mt-4 px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition-colors">
            编辑资料
          </button>
        </div>
      ),
    },
    {
      id: "notifications",
      label: "通知",
      icon: Bell,
      content: (
        <div className="p-6">
          <h2 className="text-xl font-semibold mb-3">通知设置</h2>
          <p className="text-gray-700">配置您希望接收的通知类型和频率。</p>
          <div className="mt-4">
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                className="form-checkbox text-indigo-600"
                defaultChecked
              />
              <span className="text-gray-800">接收邮件通知</span>
            </label>
          </div>
        </div>
      ),
    },
    {
      id: "settings",
      label: "系统设置",
      icon: Settings,
      content: (
        <div className="p-6">
          <h2 className="text-xl font-semibold mb-3">通用系统设置</h2>
          <p className="text-gray-700">调整应用程序的通用行为和界面选项。</p>
          <select className="mt-4 block w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500">
            <option>深色主题</option>
            <option>浅色主题</option>
          </select>
        </div>
      ),
    },
  ];

  const [activeTab, setActiveTab] = useState(tabs[0].id); // 默认激活第一个 Tab

  return (
    <div className="w-full max-w-3xl mx-auto mt-10 bg-white rounded-xl shadow-2xl overflow-hidden border border-gray-200">
      {/* Tab 导航区域 */}
      <div className="flex border-b border-gray-200 bg-gray-50">
        {tabs.map((tab) => {
          const isActive = tab.id === activeTab;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`
                flex-1 flex items-center justify-center p-4 text-sm font-medium
                hover:bg-gray-100 transition-colors duration-200
                ${
                  isActive
                    ? "text-indigo-600 border-b-2 border-indigo-600 bg-white"
                    : "text-gray-500 hover:text-gray-700"
                }
              `}
            >
              <tab.icon className="w-5 h-5 mr-2" /> {/* Lucide 图标 */}
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* Tab 内容区域 */}
      <div className="py-6 px-4">
        {tabs.find((tab) => tab.id === activeTab)?.content}
      </div>
    </div>
  );
};

export default Tabs;
