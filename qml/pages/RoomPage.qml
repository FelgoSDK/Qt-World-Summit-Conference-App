import VPlayApps 1.0
import QtQuick 2.7

Page {
  id: roomPage
  title: room
  property string room

  onPushed: amplitude.logEvent("Show Room",{"title" : title})

  AppFlickable {
    id: flick
    anchors.fill: parent
    contentWidth: roomPage.width
    contentHeight: roomPage.height
    flickableDirection: Flickable.AutoFlickIfNeeded

    PinchArea {
      width: Math.max(flick.contentWidth, flick.width)
      height: Math.max(flick.contentHeight, flick.height)

      property real initialWidth
      property real initialHeight
      onPinchStarted: {
        initialWidth = flick.contentWidth
        initialHeight = flick.contentHeight
      }

      onPinchUpdated: {
        // adjust content pos due to drag
        flick.contentX += pinch.previousCenter.x - pinch.center.x
        flick.contentY += pinch.previousCenter.y - pinch.center.y

        // resize content
        flick.resizeContent(initialWidth * pinch.scale, initialHeight * pinch.scale, pinch.center)
      }

      onPinchFinished: {
        // Move its content within bounds.
        flick.returnToBounds()
      }

      Rectangle {
        width: flick.contentWidth
        height: flick.contentHeight
        color: "white"
        AppImage {
          width: parent.width
          fillMode: AppImage.PreserveAspectFit
          property string fileName: room !== "Agenda" ? room.replace(" Room","") + ".png" : "Agenda.jpg"
          source: "../../assets/rooms/" + fileName
          MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
              flick.contentWidth = roomPage.width
              flick.contentHeight = roomPage.height
            }
          }
        }
      }
    }
  }
}
