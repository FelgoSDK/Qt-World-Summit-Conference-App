import VPlayApps 1.0
import QtQuick 2.0
import VPlay 2.0 // for game network
import "../common"

Item {
  id: page
  anchors.fill: parent

  property alias viewState: gameNetworkView.state

  // make accessible for GameNetwork component
  property alias gnView: gameNetworkView

  // make scene accessible to overwrite dp functions
  property alias scene: scene

  signal backClicked()

  // otherwise app::dp function is used with wrong scaling
  function dp(value) {
    return scene.dp(value)
  }

  // otherwise app::sp function is used with wrong scaling
  function sp(value) {
    return scene.sp(value)
  }

  Item {
    anchors.fill: parent

    // provide scaling values of app because scene uses these values for dp functions!!!
    property real uiScale: app.uiScale
    property real dpScale: app.dpScale
    property real spScale: app.spScale
    property string scaleMode: "letterbox"

    Scene {
      id: scene
      sceneGameWindow: parent
      width: portrait ? 320 : 480
      height: portrait ? 480 : 320

      VPlayGameNetworkView {
        id: gameNetworkView
        anchors.fill: parent.gameWindowAnchorItem

        // no achievements used yet, so do not show the achievements icon
        showAchievementsHeaderIcon: false
        tintColor: Theme.tintColor

        // deactivate loading of icon font and use theme icon font instead
        iconFontSource: ""
        iconFontName: Theme.iconFont.name

        onBackClicked: page.backClicked()
        Component.onCompleted: gameNetworkView.show(page.state)
      }

      // overwrite previous back icon with drawer / ios style back icon
      Rectangle {
        color: "white"
        width: dp(14) + 28
        height: 48
        anchors.top: parent.gameWindowAnchorItem.top
        anchors.left: parent.gameWindowAnchorItem.left

        ButtonBarItem {
          id: btnBarItem
          visible: page.parent && page.parent.splitViewActive !== undefined ? !page.parent.splitViewActive : true
          width: icon.width
          height: icon.height
          anchors.centerIn: parent
          mouseArea.backgroundColor: setAlpha(Theme.tintColor, 0.1)
          mouseArea.fillColor: setAlpha(Theme.tintColor, 0.1)
          onClicked: page.backClicked()

          Icon {
            id: icon
            icon: Theme.isAndroid ? "menu" : IconType.angleleft
            textItem.font.family: Theme.isAndroid ? Theme.androidIconFont.name : Theme.iconFont.name
            size: Theme.isAndroid ? 24 : 32
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
  }
}
