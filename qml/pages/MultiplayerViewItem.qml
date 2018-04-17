import VPlayApps 1.0
import QtQuick 2.0
import VPlay 2.0 // for game network
import "../common"

Item {
  id: page

  property alias viewState: multiplayerView.state

  signal backClicked()

  // make accessible for GameNetwork component
  property alias mpView: multiplayerView

  // navigationStack for pushing sup-pages as new item (may be used in custom mp view)
  property var navigationStack: null

  // page that currently holds the view
  property var parentPage: null

  VPlayMultiplayerView {
    id: multiplayerView
    anchors.fill: parent //.gameWindowAnchorItem

    tintColor: Theme.tintColor

    // deactivate loading of icon font and use theme icon font instead
    iconFontSource: ""
    iconFontName: Theme.iconFont.name

    onBackClicked: page.backClicked()
    Component.onCompleted: multiplayerView.show(page.state)
  }

  // overwrite previous back icon with drawer / ios style back icon
  Rectangle {
    color: "white"
    width: 32 + dp(8)
    height: dp(52)
    visible: multiplayerView.state === "friends" || multiplayerView.state === "inbox"

    ButtonBarItem {
      id: btnBarItem
      visible: navigationStack && navigationStack.splitViewActive ? navigationStack.depth > 2 : true
      width: icon.width
      height: icon.height
      y: (parent.height - height) * 0.5 + dp(2)
      x: (parent.width - width) * 0.5 + dp(4)
      //mouseArea.backgroundColor: Theme.navigationBar.backgroundColor
      //mouseArea.fillColor: Theme.navigationBar.backgroundColor
      mouseArea.anchors.fill: undefined
      mouseArea.width: width * 5
      mouseArea.height: height
      onClicked: page.backClicked()

      Icon {
        id: icon
        icon: Theme.isAndroid ? "menu" : IconType.angleleft
        textItem.font.family: Theme.isAndroid ? Theme.androidIconFont.name : Theme.iconFont.name
        size: Theme.isAndroid ? dp(Theme.navigationBar.defaultIconSize) : dp(32)
        color: btnBarItem.mouseArea.pressed
               ? Qt.darker(Theme.tintColor, 1.2)
               : Theme.tintColor
        anchors.centerIn: parent
      }

      function setAlpha(color, alpha) {
        return Qt.rgba(color.r,color.g,color.b, alpha)
      }
    }
  }
}
