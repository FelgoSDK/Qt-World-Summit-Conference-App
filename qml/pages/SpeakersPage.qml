import VPlayApps 1.0
import QtQuick 2.0
import "../common"

ListPage {
  id: speakersPage

  property var speakersModel: DataModel.speakers !== undefined ? DataModel.speakers : {}

  title: "Speakers"

  model: prepareSpeakers(speakersModel)
  section.property: "firstLetter"
  section.delegate: SimpleSection {
    style.compactStyle: Theme.isIos
  }

  delegate: SpeakerRow {
    speaker: modelData
    small: true
    onClicked: {
      if(Theme.isAndroid)
        speakersPage.navigationStack.popAllExceptFirstAndPush(Qt.resolvedUrl("SpeakerDetailPage.qml"), { speakerID: modelData.id })
      else
        speakersPage.navigationStack.push(Qt.resolvedUrl("SpeakerDetailPage.qml"), { speakerID: modelData.id })
    }
  }

  listView.scrollIndicatorVisible: false

  SectionSelect {
    id: sectionSelect
    anchors.right: parent.right
    target: speakersPage.listView
  }

  // prepareSpeakers - build speaker model for display
  function prepareSpeakers(speakers) {
    var model = []
    for(var i in Object.keys(speakers)){
      var speakerID = Object.keys(speakers)[i];
      var speaker = speakers[parseInt(speakerID)]
      speaker["firstLetter"] = speaker["last_name"].charAt(0).toUpperCase()
      model.push(speaker)
    }
    model.sort(compareLastName);
    return model
  }

  function compareLastName(a,b) {
    if (a.last_name < b.last_name)
      return -1;
    if (a.last_name > b.last_name)
      return 1;
    return 0;
  }
}
