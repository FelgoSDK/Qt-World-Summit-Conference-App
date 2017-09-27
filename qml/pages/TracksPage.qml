import VPlayApps 1.0
import QtQuick 2.0
import "../common"

ListPage {
  id: tracksPage

  property var tracksModel: DataModel.tracks !== undefined ? DataModel.tracks : { }

  title: "Tracks"

  model: DataModel.prepareTracks(tracksModel)

  delegate: TrackRow {
    track: modelData
    onClicked: {
      if(Theme.isAndroid)
        tracksPage.navigationStack.popAllExceptFirstAndPush(Qt.resolvedUrl("TrackDetailPage.qml"), { track: modelData })
      else
        tracksPage.navigationStack.push(Qt.resolvedUrl("TrackDetailPage.qml"), { track: modelData })
    }
  }
}
