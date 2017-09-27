import VPlayApps 1.0
import QtQuick 2.7
import VPlay 2.0 // for game network
import VPlayPlugins 1.0
import "pages"
import "common"

Rectangle {
  id: loaderItem
  anchors.fill: parent
  color: Theme.backgroundColor

  // make navigation public (required for V-Play app demo launcher)
  property Navigation navigation: mainLoader.item && mainLoader.item.navigation

  property GameNetworkViewItem gameNetworkViewItem: mainLoader.item && mainLoader.item.gameNetworkViewItem || null
  property MultiplayerViewItem multiplayerViewItem: mainLoader.item && mainLoader.item.multiplayerViewItem || null

  // storage for caching data
  WebStorage {
    id: webStorage
    property var gameWindow: app
    gameNetworkItem: gameNetwork
    clearAllAtStartup: system.desktopPlatform

    // initialize data model with stored data at startup
    Component.onCompleted: {
      DataModel.initialize(webStorage)
    }

    // update data model with fresh synchronized data
    onInitiallyInServerSyncChanged: {
      if(initiallyInServerSync)
        DataModel.initialize(webStorage)
    }
  }

  // facebook
  Facebook {
    id: facebook
    appId: "<your-fb-appid>"
    readPermissions: [ "public_profile", "email", "user_friends" ]
  }

  // game network
  VPlayGameNetwork {
    id: gameNetwork
    gameId: 406
    secret: "qtws2017github"
    gameNetworkView: gameNetworkViewItem && gameNetworkViewItem.gnView || null
    facebookItem: facebook
    defaultUserName: "User %1"

    clearAllUserDataAtStartup: system.desktopPlatform // this can be enabled during development to simulate a first-time app start
    clearOfflineSendingQueueAtStartup: true // clear any stored requests in the offline queue at app start, to avoid starting errors
    user.deviceId: system.UDID

    // update highscore with changes after scores are in sync initially
    property int addScoreWhenSynced: 0
    onUserScoresInitiallySyncedChanged: {
      if(userScoresInitiallySynced && !system.publishBuild) {
        console.log("Debug Build - reset current score of "+gameNetwork.userHighscoreForCurrentActiveLeaderboard+" to 0")
        var targetScore = 0
        if(DataModel.favorites) {
          for(var id in DataModel.favorites)
            targetScore++
        }
        gameNetwork.reportRelativeScore(targetScore - gameNetwork.userHighscoreForCurrentActiveLeaderboard)
      }
      else if(userScoresInitiallySynced && addScoreWhenSynced != 0)
        gameNetwork.reportRelativeScore(addScoreWhenSynced)
    }

    // reset / initialize data model when when GameNetwork user switches
    onUserInitiallyInSyncChanged: {
      if(!userInitiallyInSync) {
        // initially in sync changed to false -> user switched, clear favorites
        DataModel.favorites = undefined
        DataModel.initialized = false
      }
      else if(!DataModel.initialized) {
        // initially in sync changed to true again -> initialize data
        DataModel.initialize(webStorage)
      }
    }
  }

  // multiplayer
  VPlayMultiplayer {
    id: multiplayer
    gameNetworkItem: gameNetwork
    multiplayerView: multiplayerViewItem && multiplayerViewItem.mpView || null
    appKey: "<add your-appkey>"
    pushKey: "<add your pushkey>"
    notificationBar: appNotificationBar // notification bar that also takes statusBarHeight into account
  }

  AppNotificationBar {
    id: appNotificationBar
    tintColor: Theme.tintColor
  }

  Component.onCompleted: {
    loaderTimer.start()
  }

  // load main item dynamically
  Loader {
    id: mainLoader
    asynchronous: true
    visible: false
    onLoaded:{
      mainLoader.item.parent = loaderItem
      loadingFadeOut.start() // fade out loading screen (will reveal loaded item)
    }
  }

  Timer {
    id: loaderTimer
    interval: 500
    onTriggered: mainLoader.source = Qt.resolvedUrl("QtWSMainItem.qml")
  }

  // loading screen
  Rectangle {
    id: loading
    anchors.fill: parent
    color: "#f0f1f2"
    z: 1

    Column {
      anchors.centerIn: parent
      spacing: dp(30)

      // Qt image
      AppImage {
        id: loadImage
        width: dp(92)
        fillMode: AppImage.PreserveAspectFit
        source: "../assets/Qt_logo.png"
        anchors.horizontalCenter: parent.horizontalCenter
      }

      // Loading text
      AppText {
        text: "fetching conference data"
        color: Theme.secondaryTextColor
        font.pixelSize: sp(14)
        anchors.horizontalCenter: parent.horizontalCenter
      }

      // Spinner
      Item {
        id: loadSpinner
        width: dp(30)
        height: dp(30)
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
          width: dp(10)
          height: dp(10)
          radius: width/2
          color: "#888"
          anchors.horizontalCenter: parent.horizontalCenter
        }
        Rectangle {
          width: dp(10)
          height: dp(10)
          radius: width/2
          color: "#888"
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
        }

        RotationAnimator {
          target: loadSpinner
          running: true
          loops: Animation.Infinite
          from: 0
          to: 360
          duration: 2000
        }
      }

      // fade out
      NumberAnimation {
        id: loadingFadeOut
        target: loading
        property: "opacity"
        to: 0
        duration: 300
      }
    }
  }

  Connections {
    target: getApplication()

    // load data if not available and device goes online
    onIsOnlineChanged: {
      if(!DataModel.loaded && isOnline)
        loadDataTimer.start() // use timer to delay load as immediate calls might not get through (network not ready yet)
    }
  }

  // timer to load data after 1 second delay when going online
  Timer {
    id: loadDataTimer
    interval: 1000
    onTriggered: DataModel.loadData()
  }

  // we set the lightness of the used track colors based on the Theme.backgroundColor
  // this could be done with a simple property binding, but that strangely causes issues on Linux Qt 5.8
  // which is why this workaround with manual signal handling is used:
  Item {
    id: trackColorBindingFix
    property color baseTrackColor
    property var baseTrackLightness

    Component.onCompleted: updateBaseTrackLightness()
    Connections {
      target: Theme
      onBackgroundColorChanged: trackColorBindingFix.updateBaseTrackLightness()
    }

    function updateBaseTrackLightness() {
      trackColorBindingFix.baseTrackColor = Theme.backgroundColor
      trackColorBindingFix.baseTrackLightness = colorToHsl(trackColorBindingFix.baseTrackColor)[2]
    }
  }

  // getTrackColor - determines track color
  function getTrackColor(track) {
    if(!DataModel.tracks || DataModel.tracks[track] === undefined)
      return Theme.secondaryTextColor

    var light = 0.45 + 0.25 * (0.5 - trackColorBindingFix.baseTrackLightness)
    return Qt.hsla(DataModel.tracks[track], 1, light, 1)
  }

  // color to HSL conversion
  function colorToHsl(color) {
    var r = color.r /= 255
    var g = color.g /= 255
    var b = color.b /= 255
    var max = Math.max(r, g, b), min = Math.min(r, g, b);
    var h, s, l = (max + min) / 2;

    if(max == min) {
      h = s = 0; // achromatic
    }
    else {
      var d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch(max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
      }
      h /= 6;
    }
    return [h, s, l];
  }

  // scheduleNotificationsForFavorites
  function scheduleNotificationsForFavorites() {
    if(typeof notificationManager === 'undefined')
      return

    notificationManager.cancelAllNotifications()
    if(!DataModel.notificationsEnabled || !DataModel.favorites || !DataModel.talks)
      return

    for(var idx in DataModel.favorites) {
      var talkId = DataModel.favorites[idx]
      scheduleNotificationForTalk(talkId)
    }

    // add notification before world summit starts!
    var nowTime = new Date().getTime()
    var eveningBeforeConferenceTime = new Date("2017-10-10T21:00.000"+DataModel.timeZone).getTime()
    if(nowTime < eveningBeforeConferenceTime) {
      var text = "V-Play wishes all the best for Qt World Summit 2016!"
      var notification = {
        notificationId: -1,
        message: text,
        timestamp: Math.round(eveningBeforeConferenceTime / 1000) // utc seconds
      }
      notificationManager.schedule(notification)
    }
  }

  // scheduleNotificationForTalk
  function scheduleNotificationForTalk(talkId) {
    if(DataModel.loaded && DataModel.talks && DataModel.talks[talkId]) {
      var talk = DataModel.talks[talkId]
      var text = talk["title"]+" starts "+talk.start+" at "+talk["room"]+"."

      var nowTime = new Date().getTime()
      var utcDateStr = talk.day+"T"+talk.start+".000"+DataModel.timeZone
      var notificationTime = new Date(utcDateStr).getTime()
      notificationTime = notificationTime - 10 * 60 * 1000 // 10 minutes before

      if(nowTime < notificationTime) {
        var notification = {
          notificationId: talkId,
          message: text,
          timestamp: Math.round(notificationTime / 1000) // utc seconds
        }
        notificationManager.schedule(notification)
      }
    }
  }
}
