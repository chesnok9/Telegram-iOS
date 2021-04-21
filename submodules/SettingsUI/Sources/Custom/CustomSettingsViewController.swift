//
//  CustomSettingsViewController.swift
//  _idx_SettingsUI_D99E4D6D_ios_min9.0
//
//  Created by Thu Le on 21/04/2021.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import SearchUI

public class CustomSettingsViewController: ViewController {
    private let context: AccountContext
    
    private var controllerNode: CustomSettingsViewControllerNode {
        return self.displayNode as! CustomSettingsViewControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = "Custom Settings"
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = "Custom Settings"
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = CustomSettingsViewControllerNode(context: self.context, presentationData: self.presentationData, navigationBar: self.navigationBar!, requestActivateSearch: { [weak self] in
            
        }, requestDeactivateSearch: { [weak self] in
            
        }, updateCanStartEditing: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
        
        self.controllerNode.listNode.visibleContentOffsetChanged = { [weak self] offset in
        }
        
        self.controllerNode.listNode.didEndScrolling = { [weak self] in
        }
        
        self._ready.set(self.controllerNode._ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, transition: transition)
    }
    
    @objc private func editPressed() {
        self.controllerNode.toggleEditing()
    }
}

