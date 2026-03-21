#!/usr/bin/swift
import AppKit
import ObjectiveC

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
print("Class: \(type(of: item))")
print("isVisible: \(item.isVisible)")

// NSSceneStatusItem의 모든 메서드 출력
var count: UInt32 = 0
var cls: AnyClass? = type(of: item) as AnyClass
while let c = cls {
    let methods = class_copyMethodList(c, &count)
    if count > 0 {
        print("\n[\(NSStringFromClass(c))]")
        for i in 0..<count {
            let method = methods![Int(i)]
            let sel = method_getName(method)
            print("  \(NSStringFromSelector(sel))")
        }
    }
    free(methods)
    cls = class_getSuperclass(c)
    if cls == NSObject.self { break }
}

// 유망한 메서드 시도
let candidates = ["show", "_show", "activate", "_activate", "makeVisible",
                  "_makeVisible", "requestDisplay", "becomeActive", "setVisible:"]
for name in candidates {
    let sel = NSSelectorFromString(name)
    if item.responds(to: sel) {
        print("\n✓ Found: \(name) — calling it")
        item.perform(sel)
    }
}

// isVisible 강제 설정
item.isVisible = true
print("\nAfter forcing isVisible=true: \(item.isVisible)")

RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
