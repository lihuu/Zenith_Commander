import Combine
import Foundation
import os.log
import SwiftUI

/// A thin reducer layer that routes actions and keeps `AppState` as the state holder.
///
/// NOTE:
/// - This is an incremental refactor: the reducer currently calls existing `AppState` helper methods.
/// - Next step is to progressively move side-effectful helpers (file operations, tool runs, etc.) behind services
///   and/or into reducer-owned helpers.
@MainActor
struct AppReducer {
    func reduce(_ action: AppAction, state: AppState) async {
        switch action {
        case .none:
            break
        case let .mode(modeAction):
            state.handleAction(modeAction)
        case let .pane(paneAction):
            state.handleAction(paneAction)
        case let .paneAsync(paneAsyncAction):
            await state.handleAction(paneAsyncAction)
        case let .file(fileAction):
            await state.handleAction(fileAction)
        case let .ui(uiAction):
            state.handleAction(uiAction)
        case let .command(commandAction):
            state.handleAction(commandAction)
        case let .commandAsync(commandAsyncAction):
            await state.handleAction(commandAsyncAction)
        case let .filter(filterAction):
            state.handleAction(filterAction)
        case let .drive(driveAction):
            await state.handleAction(driveAction)
        case let .moveCursor(direction):
            await state.moveCursor(direction)
        case let .moveVisualCursor(direction):
            await state.moveVisualCursor(direction)

        // MARK: - 鼠标操作
        case let .mouseClick(index, paneSide):
            state.handleMouseClick(at: index, paneSide: paneSide)
        case let .mouseCommandClick(index, paneSide):
            state.handleMouseCommandClick(at: index, paneSide: paneSide)
        case let .mouseShiftClick(index, paneSide):
            state.handleMouseShiftClick(at: index, paneSide: paneSide)
        case let .mouseDoubleClick(fileId, paneSide):
            await state.handleMouseDoubleClick(
                fileId: fileId,
                paneSide: paneSide
            )
        }
    }
}