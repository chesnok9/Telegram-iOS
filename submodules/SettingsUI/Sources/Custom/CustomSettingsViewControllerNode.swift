//
//  CustomSettingsViewControllerNode.swift
//  _idx_SettingsUI_D99E4D6D_ios_min9.0
//
//  Created by Thu Le on 21/04/2021.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import ItemListUI
import PresentationDataUtils
import AccountContext
import ShareController
import SearchBarNode
import SearchUI
import UndoUI

final class CustomSettingsViewControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let navigationBar: NavigationBar
    private let requestActivateSearch: () -> Void
    private let requestDeactivateSearch: () -> Void
    private let present: (ViewController, Any?) -> Void
    
    private var didSetReady = false
    let _ready = ValuePromise<Bool>()
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    let listNode: ListView
    private var queuedTransitions: [LanguageListNodeTransition] = []
    private var searchDisplayController: SearchDisplayController?
    
    private let presentationDataValue = Promise<PresentationData>()
    private var updatedDisposable: Disposable?
    private var listDisposable: Disposable?
    private let applyDisposable = MetaDisposable()
    
    private var currentListState: LocalizationListState?
    private let applyingCode = Promise<String?>(nil)
    private let isEditing = ValuePromise<Bool>(false)
    private var isEditingValue: Bool = false {
        didSet {
            self.isEditing.set(self.isEditingValue)
        }
    }
    
    init(context: AccountContext, presentationData: PresentationData, navigationBar: NavigationBar, requestActivateSearch: @escaping () -> Void, requestDeactivateSearch: @escaping () -> Void, updateCanStartEditing: @escaping (Bool?) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataValue.set(.single(presentationData))
        self.navigationBar = navigationBar
        self.requestActivateSearch = requestActivateSearch
        self.requestDeactivateSearch = requestDeactivateSearch
        self.present = present

        self.listNode = ListView()
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).0
        }
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.addSubnode(self.listNode)
        
        let openSearch: () -> Void = {
            requestActivateSearch()
        }
        
        let revealedCode = Promise<String?>(nil)
        var revealedCodeValue: String?
        let setItemWithRevealedOptions: (String?, String?) -> Void = { id, fromId in
            if (id == nil && fromId == revealedCodeValue) || (id != nil && fromId == nil) {
                revealedCodeValue = id
                revealedCode.set(.single(id))
            }
        }
        
        let removeItem: (String) -> Void = { id in
            let _ = (context.account.postbox.transaction { transaction -> Signal<LocalizationInfo?, NoError> in
                removeSavedLocalization(transaction: transaction, languageCode: id)
                let state = transaction.getPreferencesEntry(key: PreferencesKeys.localizationListState) as? LocalizationListState
                return context.sharedContext.accountManager.transaction { transaction -> LocalizationInfo? in
                    if let settings = transaction.getSharedData(SharedDataKeys.localizationSettings) as? LocalizationSettings, let state = state {
                        if settings.primaryComponent.languageCode == id {
                            for item in state.availableOfficialLocalizations {
                                if item.languageCode == "en" {
                                    return item
                                }
                            }
                        }
                    }
                    return nil
                }
            }
            |> switchToLatest
            |> deliverOnMainQueue).start(next: { [weak self] info in
                if revealedCodeValue == id {
                    revealedCodeValue = nil
                    revealedCode.set(.single(nil))
                }
                if let info = info {
                    self?.selectLocalization(info)
                }
            })
        }
        
        let preferencesKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.localizationListState]))
        let previousState = Atomic<LocalizationListState?>(value: nil)
        let previousEntriesHolder = Atomic<([LanguageListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.listDisposable = combineLatest(queue: .mainQueue(), context.account.postbox.combinedView(keys: [preferencesKey]), context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings]), self.presentationDataValue.get(), self.applyingCode.get(), revealedCode.get(), self.isEditing.get()).start(next: { [weak self] view, sharedData, presentationData, applyingCode, revealedCode, isEditing in
            guard let strongSelf = self else {
                return
            }
                        
            var entries: [LanguageListEntry] = []
            var activeLanguageCode: String?
            if let localizationSettings = sharedData.entries[SharedDataKeys.localizationSettings] as? LocalizationSettings {
                activeLanguageCode = localizationSettings.primaryComponent.languageCode
            }
            var existingIds = Set<String>()
            
            let localizationListState = (view.views[preferencesKey] as? PreferencesView)?.values[PreferencesKeys.localizationListState] as? LocalizationListState
            if let localizationListState = localizationListState, !localizationListState.availableOfficialLocalizations.isEmpty {
                strongSelf.currentListState = localizationListState
                
                let availableSavedLocalizations = localizationListState.availableSavedLocalizations.filter({ info in !localizationListState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
                if availableSavedLocalizations.isEmpty {
                    updateCanStartEditing(nil)
                } else {
                    updateCanStartEditing(isEditing)
                }
                if !availableSavedLocalizations.isEmpty {
                    for info in availableSavedLocalizations {
                        if existingIds.contains(info.languageCode) {
                            continue
                        }
                        existingIds.insert(info.languageCode)
                        entries.append(.localization(index: entries.count, info: info, type: .unofficial, selected: info.languageCode == activeLanguageCode, activity: applyingCode == info.languageCode, revealed: revealedCode == info.languageCode, editing: isEditing))
                    }
                }
                for info in localizationListState.availableOfficialLocalizations {
                    if existingIds.contains(info.languageCode) {
                        continue
                    }
                    existingIds.insert(info.languageCode)
                    entries.append(.localization(index: entries.count, info: info, type: .official, selected: info.languageCode == activeLanguageCode, activity: applyingCode == info.languageCode, revealed: revealedCode == info.languageCode, editing: false))
                }
            } else {
                for _ in 0 ..< 15 {
                    entries.append(.localization(index: entries.count, info: nil, type: .official, selected: false, activity: false, revealed: false, editing: false))
                }
            }
            
            let previousState = previousState.swap(localizationListState)
            
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            let transition = preparedLanguageListNodeTransition(presentationData: presentationData, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, openSearch: openSearch, selectLocalization: { [weak self] info in self?.selectLocalization(info) }, setItemWithRevealedOptions: setItemWithRevealedOptions, removeItem: removeItem, firstTime: previousEntriesAndPresentationData == nil, isLoading: entries.isEmpty, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings, animated: (previousEntriesAndPresentationData?.0.count ?? 0) >= entries.count, crossfade: (previousState == nil) != (localizationListState == nil))
            strongSelf.enqueueTransition(transition)
        })
        self.updatedDisposable = synchronizedLocalizationListState(postbox: context.account.postbox, network: context.account.network).start()
    }
    
    deinit {
        self.listDisposable?.dispose()
        self.updatedDisposable?.dispose()
        self.applyDisposable.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationDataValue.set(.single(presentationData))
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
        self.searchDisplayController?.updatePresentationData(presentationData)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var listInsets = layout.insets(options: [.input])
        listInsets.top += navigationBarHeight
        listInsets.left += layout.safeInsets.left
        listInsets.right += layout.safeInsets.right
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: listInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: LanguageListNodeTransition) {
        self.queuedTransitions.append(transition)
        
        if self.containerLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        guard let _ = self.containerLayout else {
            return
        }
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            
            var options = ListViewDeleteAndInsertOptions()
            if transition.firstTime {
                options.insert(.Synchronous)
                options.insert(.LowLatency)
            } else if transition.crossfade {
                options.insert(.AnimateCrossfade)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            }
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            })
        }
    }
    
    private func selectLocalization(_ info: LocalizationInfo) -> Void {
        
    }
    
    func toggleEditing() {
        self.isEditingValue = !self.isEditingValue
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: LocalizationListSearchContainerNode(context: self.context, listState: self.currentListState ?? LocalizationListState.defaultSettings, selectLocalization: { [weak self] info in self?.selectLocalization(info) }, applyingCode: self.applyingCode.get()), cancel: { [weak self] in
            self?.requestDeactivateSearch()
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: strongSelf.navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
