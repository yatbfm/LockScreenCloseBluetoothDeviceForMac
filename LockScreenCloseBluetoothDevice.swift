import Cocoa
import Foundation
import IOBluetooth

// 扩展连接功能
extension IOBluetoothDevice {
  // 尝试连接设备（同步方式）
  func connectDevice() -> Bool {
    if self.isConnected() {
      // print("\(self.name ?? "未知设备") 已处于连接状态")
      return true
    }

    // 修正参数类型（使用UInt32替代已废弃的IOBluetoothPageTimeout）
    let timeout = UInt32(10)  // 单位：秒
    let result = self.openConnection(
      nil,
      withPageTimeout: BluetoothHCIPageTimeout(timeout),  // 修正参数类型
      authenticationRequired: true
    )

    if result == kIOReturnSuccess {
      // print("连接成功：\(self.name ?? "未知设备")")
      return true
    } else {
      // print("连接失败：\(self.name ?? "未知设备") 错误码: \(result)")
      return false
    }
  }
  // 断开设备连接
  func disconnectDevice() -> Bool {
    guard self.isConnected() else {
      // print("\(self.name ?? "未知设备") 未处于连接状态")
      return false
    }

    let result = self.closeConnection()
    if result == kIOReturnSuccess {
      // print("断开成功：\(self.name ?? "未知设备")")
      return true
    } else {
      // print("断开失败：\(self.name ?? "未知设备") 错误码: \(result)")
      return false
    }
  }
}

class ScreenLockDetector {
  private var workspace: NSWorkspace
  private var myDeviceNameList: [String]
  private var vitalityEditionDevices: [IOBluetoothDevice]

  init(myDeviceNameList: [String] = []) {
    self.workspace = NSWorkspace.shared
    self.vitalityEditionDevices = []
    self.myDeviceNameList = myDeviceNameList
    setupNotifications()
  }

  private func setupNotifications() {

    vitalityEditionDevices = findVitalityEditionDevices()

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(method_screenIsLocked),
      name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
      object: nil
    )

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(method_screenIsUnlocked),
      name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
      object: nil
    )

    // 监听屏幕锁定通知
    workspace.notificationCenter.addObserver(
      self,
      selector: #selector(screenDidSleep),
      name: NSWorkspace.screensDidSleepNotification,
      object: nil
    )

    // 监听屏幕解锁通知
    workspace.notificationCenter.addObserver(
      self,
      selector: #selector(screenDidUnSleep),
      name: NSWorkspace.screensDidWakeNotification,
      object: nil
    )
  }

  private func findVitalityEditionDevices() -> [IOBluetoothDevice] {
    // 获取所有已配对蓝牙设备（需要开启沙盒的蓝牙权限）
    guard let pairedDevices = IOBluetoothDevice.pairedDevices() else {
      // print("没有找到已配对设备")
      return []
    }

    // 转换为IOBluetoothDevice对象数组
    let devices = pairedDevices.compactMap { $0 as? IOBluetoothDevice }

    var vitalityDevices = Set<IOBluetoothDevice>()

    myDeviceNameList.forEach { deviceName in
      vitalityDevices.formUnion(
        devices.filter { device in
          // 使用nil合并运算符处理可能为nil的设备名称
          (device.name ?? "").contains(deviceName)
        })
    }

    // 筛选名称包含"myDeviceName"的设备
    return Array(vitalityDevices)
  }

  private func setConnectStatus(status: Bool) {
    if vitalityEditionDevices.isEmpty {
      // print("未找到名称包含 " + myDeviceNameList.joined(separator: ", ") + " 的设备")
    } else {
      // print("找到匹配设备：")
      vitalityEditionDevices.forEach { device in
        // print("设备名称: \(device.name ?? "未知设备")")
        // print("地址: \(device.addressString ?? "未知地址")")
        // print("-------------------")
        if status {
          _ = device.connectDevice()
        } else {
          _ = device.disconnectDevice()
        }
      }
    }
  }

  //屏幕锁住      //"com.apple.screenIsLocked"
  @objc func method_screenIsLocked() {
    // print("method_screenIsLocked")
    setConnectStatus(status: false)
  }

  //屏幕解锁      //"com.apple.screenIsUnlocked"
  @objc func method_screenIsUnlocked() {
    // print("method_screenIsUnlocked")
    setConnectStatus(status: true)
  }

  @objc private func screenDidSleep() {
    // print("睡眠")
  }

  @objc private func screenDidUnSleep() {
    // print("解除睡眠")
  }

  deinit {
    workspace.notificationCenter.removeObserver(self)
    DistributedNotificationCenter.default().removeObserver(self)
  }
}

// 使用示例
class AppDelegate: NSObject, NSApplicationDelegate {
  private var screenLockDetector: ScreenLockDetector?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // print("应用程序启动，开始监听屏幕锁定事件...")
    var myDeviceNameList: [String] = []
    let args = CommandLine.arguments
    for (index, arg) in args.enumerated() {
      if index > 0 {
        myDeviceNameList.append(arg)
      }
    }
    // print(myDeviceNameList)
    screenLockDetector = ScreenLockDetector(myDeviceNameList: myDeviceNameList)
  }

  func applicationWillTerminate(_ notification: Notification) {
    // print("应用程序即将退出")
  }
}

// 主程序入口
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 运行应用程序
app.run()
