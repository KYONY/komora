import AppKit
import ObjectiveC
_ = NSApplication.shared; _ = NSStatusBar.system
let want = ["_startStatusItemDrag:","_dragStatusItemWithOffset:","_completeStatusItemDrag","_beginCreationDragWithHitPoint:","_itemMovedDuringDrag","_isDragging","_updateDragState","_allowItemDragging","_supportsDragging","_setHideFromBar:","_hideFromBar","_neverClip","_approximatedWindowFrame","_restorePreferencesFromAutosaveName","_clearAutosavedState","_uninstall","_overflowSpecifierPriority","_setOverflowSpecifierPriority:","_setLayoutIndex:","_priority","_systemInsertOrder","_displayIdentifier","_setDisplayIdentifier:","_currentPreferredPosition","_savedPreferredPosition","_autosavePosition","_setVisible:temporary:","_moveToScreenContainingActiveMenuBar","_preferredPositionDefaultsKey","_isHidden","_setHidden:","_allowReplication","_isReplicant","_statusItemWithLength:withPriority:","_statusItemWithLength:systemInsertOrder:","_initWithStatusBar:length:priority:systemInsertOrder:activeItem:","_statusItems:setHidden:","_itemInStatusBar:withLength:withPriority:systemInsertOrder:","_useScenes","_workspaceServiceIdentifier","_localWorkspaceServiceIdentifier"]
for cname in ["NSStatusItem","NSStatusBar"] {
  let c: AnyClass = NSClassFromString(cname)!
  for cls in [c, object_getClass(c)!] {
    var n: UInt32 = 0; let ms = class_copyMethodList(cls, &n)!
    for i in 0..<Int(n) { let s = NSStringFromSelector(method_getName(ms[i])); if want.contains(s) { print(cname, cls == c ? "-" : "+", s, String(cString: method_getTypeEncoding(ms[i])!)) } }
  }
}
// also all other methods of NSStatusItem not printed earlier
