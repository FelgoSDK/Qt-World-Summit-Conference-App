import VPlayApps 1.0
import QtQuick 2.0
import VPlay 2.0 // for game network
import QtGraphicalEffects 1.0
import "pages"
import "common"

Item {
  anchors.fill: parent

  // make navigation public
  property alias navigation: navigation

  // game network / multiplayer view (only once per app)
  property alias gameNetworkViewItem: gameNetworkViewItem //publicly accessible
  property alias multiplayerViewItem: multiplayerViewItem //publicly accessible

  Component.onCompleted: {
    buildPlatformNavigation()  // apply platform specific navigation changes
    if(system.publishBuild) {
      // give 1 point for opening the app
      if(gameNetwork.userScoresInitiallySynced)
        gameNetwork.reportRelativeScore(1)
      else
        gameNetwork.addScoreWhenSynced += 1
    }
    notificationTimer.start() // schedule notifications after app was started
  }

  // timer to schedule notifications 4 seconds after app startup
  Timer {
    id: notificationTimer
    interval: 4000
    onTriggered: scheduleNotificationsForFavorites()
  }

  // handle data loading failed
  Connections {
    target: DataModel
    onLoadingFailed: NativeDialog.confirm("Failed to update conference data, please try again later.")
    onFavoriteAdded: {
      if(gameNetwork.userScoresInitiallySynced)
        gameNetwork.reportRelativeScore(1)
      else
        gameNetwork.addScoreWhenSynced += 1
    }
    onFavoriteRemoved: {
      if(gameNetwork.userScoresInitiallySynced && gameNetwork.userHighscoreForCurrentActiveLeaderboard > 0)
        gameNetwork.reportRelativeScore(-1)
      else if(!gameNetwork.userScoresInitiallySynced)
        gameNetwork.addScoreWhenSynced -= 1
    }
    onFavoritesChanged: scheduleNotificationsForFavorites()
    onNotificationsEnabledChanged: {
      scheduleNotificationsForFavorites()
    }
  }

  // handle theme switching (apply navigation changes)
  Connections {
    target: Theme
    onPlatformChanged: buildPlatformNavigation()
  }

  // app navigation
  Navigation {
    id: navigation
    property var currentPage: {
      if(!currentNavigationItem)
        return null

      if(currentNavigationItem.navigationStack)
        return currentNavigationItem.navigationStack.currentPage
      else
        return currentNavigationItem.page
    }

    // automatically load data if not loaded and schedule/favorites page is opened
    onCurrentIndexChanged: {
      if(currentIndex > 0 && currentIndex < 3) {
        if(!DataModel.loaded && isOnline)
          DataModel.loadData()
      }
    }

    // Android drawer header item
    headerView: Item {
      width: parent.width
      height: dp(75) + Theme.statusBarHeight
      clip: true

      Rectangle {
        anchors.fill: parent
        color: Theme.tintColor
      }

      AppImage {
        width: parent.width
        fillMode: AppImage.PreserveAspectFit
        source: "../assets/venue_photo.jpg"
        anchors.verticalCenter: parent.verticalCenter
      }

      AppImage {
        width: parent.width
        fillMode: AppImage.PreserveAspectFit
        source: "../assets/venue_photo.jpg"
        anchors.verticalCenter: parent.verticalCenter
        opacity: 0.5
        layer.enabled: true
        layer.effect: Colorize {
          id: titleImgColorize
          lightness: 0.1
          saturation: 0.5

          // we set the hue for the colorize effect based on the Theme.tintColor
          // this could be done with a simple property binding, but that strangely causes issues on Linux Qt 5.8
          // which is why this workaround with manual signal handling is used:
          property color baseColor
          Component.onCompleted: updateHue()
          Connections {
            target: app
            onSecondaryTintColorChanged: titleImgColorize.updateHue()
          }
          function updateHue() {
            titleImgColorize.baseColor = app.secondaryTintColor
            var hslColor = loaderItem.colorToHsl(titleImgColorize.baseColor)
            titleImgColorize.hue = hslColor[0]
            titleImgColorize.saturation = hslColor[1]
            titleImgColorize.lightness = hslColor[2]
          }
        }
      }

      AppImage {
        width: parent.width * 0.75
        source: "../assets/QtWS2017_logo_white.png"
        fillMode: AppImage.PreserveAspectFit
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.statusBarHeight + ((parent.height - Theme.statusBarHeight) - height) * 0.5
        layer.enabled: true
        layer.effect: DropShadow {
          color: Qt.rgba(0,0,0,0.5)
          radius: 16
          samples: 16
        }
      }
    }

    NavigationItem {
      title: "About"
      iconComponent: Item {
        height: parent.height
        width: height

        property bool selected: parent && parent.selected

        Icon {
          anchors.centerIn: parent
          width: height
          height: parent.height
          icon: IconType.home
          color: !parent.selected ? Theme.textColor  : Theme.tintColor
          visible: !vplayIcon.visible
        }

        Image {
          id: vplayIcon
          height: parent.height
          anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
          fillMode: Image.PreserveAspectFit
          source: !parent.selected ? (Theme.isAndroid ? "../assets/Qt_logo_Android_off.png" : "../assets/Qt_logo_iOS_off.png") : "../assets/Qt_logo.png"
          visible: Theme.isIos || Theme.backgroundColor.r == 1 && Theme.backgroundColor.g == 1 && Theme.backgroundColor.b == 1
        }
      }

      NavigationStack {
        navigationBarShadow: false
        MainPage {}
      }
    } // main

    NavigationItem {
      title: "Timetable"
      icon: IconType.calendaro

      NavigationStack {
        splitView: tablet && landscape
        // if first page, reset leftColumnIndex (may change when searching)
        onTransitionFinished: {
          if(depth === 1)
            leftColumnIndex = 0
        }

        TimetablePage { }
      }
    } // timetable

    NavigationItem {
      title: "Favorites"
      icon: IconType.star

      NavigationStack {
        splitView: tablet && landscape
        FavoritesPage {}
      }
    } // favorites

    NavigationItem {
      title: "Speakers"
      icon: IconType.microphone

      NavigationStack {
        splitView: landscape && tablet
        SpeakersPage {}
      }
    } // speakers
  } // nav

  // components for dynamic tabs/drawer entries
  Component {
    id: tracksNavItemComponent
    NavigationItem {
      title: "Tracks"
      icon: IconType.tag

      NavigationStack {
        splitView: landscape && tablet
        TracksPage {}
      }
    }
  } // tracks

  // components for dynamic tabs/drawer entries
  Component {
    id: venueNavItemComponent
    NavigationItem {
      title: "Venue"
      icon: IconType.building

      NavigationStack {
        VenuePage {}
      }
    }
  } // venue

  // components for dynamic tabs/drawer entries
  Component {
    id: settingsNavItemComponent
    NavigationItem {
      title: "Settings"
      icon: IconType.gears

      NavigationStack {
        SettingsPage {}
      }
    }
  } // settings

  Component {
    id: moreNavItemComponent
    NavigationItem {
      title: "More"
      icon: IconType.ellipsish

      NavigationStack {
        splitView: tablet && landscape
        MorePage {}
      }
    }
  } // more

  // dummyNavItemComponent for adding gameNetwork/multiplayer pages to navigation (android)
  Component {
    id: dummyNavItemComponent
    NavigationItem {
      id: dummyNavItem
      title: "Leaderboard"
      icon: IconType.flagcheckered // gamepad, futbolo, group, listol. sortnumericasc

      property var targetItem
      property string targetState

      Page {
        id: dummyPage
        navigationBarHidden: true
        title: "DummyPage"

        property Item targetItem: dummyNavItem.targetItem
        property string targetState: dummyNavItem.targetState

        // connection to navigation, show target page if dummy is selected
        Connections {
          target: navigation || null
          onCurrentNavigationItemChanged: {
            if(navigation.currentNavigationItem === dummyNavItem) {
              gameNetworkViewItem.parent = hiddenItemContainer
              multiplayerViewItem.parent = hiddenItemContainer
              dummyPage.targetItem.viewState = dummyPage.targetState
              dummyPage.targetItem.parent = contentArea
            }
          }
        }

        // connection to target page, listen to state change and switch active navitem
        Connections {
          target: navigation.currentNavigationItem === dummyNavItem && dummyNavItem.targetItem === gameNetworkViewItem && gameNetworkViewItem.gnView || null
          onStateChanged: {
            var targetItem = dummyNavItem.targetItem
            var state = targetItem.viewState
            if(Theme.isAndroid && state !== dummyNavItem.targetState) {
              if(state === "leaderboard")
                navigation.currentIndex = 7
              else if(state === "profile")
                navigation.currentIndex = 8
            }
          }
        }

        Item {
          id: contentArea
          y: Theme.statusBarHeight
          width: parent.width
          height: parent.height - y

          property bool splitViewActive: dummyPage.navigationStack && dummyPage.navigationStack.splitViewActive
        }
      }
    }
  } // dummy

  // dummy page component for wrapping gn/multiplayer views on iOS
  Component {
    id: dummyPageComponent

    Page {
      id: dummyPage
      navigationBarHidden: true
      title: "DummyPage"

      property Item targetItem
      property string targetState
      Component.onCompleted: {
        gameNetworkViewItem.parent = hiddenItemContainer
        multiplayerViewItem.parent = hiddenItemContainer
        targetItem.viewState = targetState
        targetItem.parent = contentArea
      }

      Item {
        id: contentArea
        y: Theme.statusBarHeight
        width: parent.width
        height: parent.height - y

        property bool splitViewActive: dummyPage.navigationStack && dummyPage.navigationStack.splitViewActive
      }
    }
  }

  Item {
    id: hiddenItemContainer
    visible: false
    anchors.fill: parent

    GameNetworkViewItem {
      id: gameNetworkViewItem
      state: "leaderboard"
      anchors.fill: parent
      onBackClicked: {
        if(Theme.isAndroid)
          navigation.drawer.open()
        else {
          gameNetworkViewItem.parent = hiddenItemContainer
          navigation.currentPage.navigationStack.popAllExceptFirst()
        }
      }
    }

    // multiplayer view (only once per app)
    MultiplayerViewItem {
      id: multiplayerViewItem
      state: "inbox"
      anchors.fill: parent
      onBackClicked: {
        if(Theme.isAndroid)
          navigation.drawer.open()
        else {
          multiplayerViewItem.parent = hiddenItemContainer
          navigation.currentPage.navigationStack.popAllExceptFirst()
        }
      }
    }
  }

  // addDummyNavItem - adds dummy nav item to app-drawer, which opens GameNetwork/Multiplayer page
  function addDummyNavItem(targetItem, targetState, title, icon) {
    navigation.addNavigationItem(dummyNavItemComponent)
    var dummy = navigation.getNavigationItem(navigation.count - 1)
    dummy.targetItem = targetItem
    dummy.targetState = targetState
    dummy.title = title
    dummy.icon = icon
  }

  // buildPlatformNavigation - apply navigation changes for different platforms
  function buildPlatformNavigation() {
    var activeTitle = navigation.currentPage ? navigation.currentPage.title : ""
    var targetItem = navigation.currentPage && navigation.currentPage.targetItem || null
    var targetState = navigation.currentPage && navigation.currentPage.targetState ? navigation.currentPage.targetState : ""

    // hide multiplayer/gamenetwork views
    gameNetworkViewItem.parent = hiddenItemContainer
    multiplayerViewItem.parent = hiddenItemContainer

    // remove previous platform specific pages
    while(navigation.count > 4) {
      navigation.removeNavigationItem(navigation.count - 1)
    }

    // add new platform specific pages
    if(Theme.isAndroid) {
      navigation.addNavigationItem(tracksNavItemComponent)
      navigation.addNavigationItem(venueNavItemComponent)
      navigation.addNavigationItem(settingsNavItemComponent)
      addDummyNavItem(gameNetworkViewItem, "leaderboard", "Leaderboard", IconType.flagcheckered)
      addDummyNavItem(gameNetworkViewItem, "profile", "Profile", IconType.user)
      addDummyNavItem(multiplayerViewItem, "inbox", "Chat", IconType.comment)
      addDummyNavItem(multiplayerViewItem, "friends", "Friends", IconType.group)

      if(activeTitle === "DummyPage" || activeTitle === "More") { // "More" is used when splitView is active
        if(targetItem === multiplayerViewItem && targetState === "friends")
          navigation.currentIndex = 10
        else if (targetItem === multiplayerViewItem)
          navigation.currentIndex = 9
        else if(targetItem === gameNetworkViewItem && targetState === "profile")
          navigation.currentIndex = 8
        else if (targetItem === gameNetworkViewItem)
          navigation.currentIndex = 7
      }
      else if(activeTitle === "Settings")
        navigation.currentIndex = 6
      else if(activeTitle === "Venue")
        navigation.currentIndex = 5
      else if(activeTitle === "Tracks")
        navigation.currentIndex = 4
    }
    else {
      navigation.addNavigationItem(moreNavItemComponent)

      if(!navigation.currentPage)
        return

      // open settings page when active
      if(activeTitle === "DummyPage") {
        navigation.currentIndex = navigation.count - 1 // open more page
        if(targetItem === multiplayerViewItem && targetState === "friends")
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: multiplayerViewItem, targetState: "friends" })
        else if (targetItem === multiplayerViewItem)
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: multiplayerViewItem, targetState: "inbox" })
        else if(targetItem === gameNetworkViewItem && targetState === "profile")
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: gameNetworkViewItem, targetState: "profile" })
        else if (targetItem === gameNetworkViewItem)
          navigation.currentPage.navigationStack.push(dummyPageComponent, { targetItem: gameNetworkViewItem, targetState: "leaderboard" })
      }
      else if(activeTitle === "Settings") {
        navigation.currentIndex = navigation.count - 1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/SettingsPage.qml"))
      }
      else if(activeTitle === "Venue") {
        navigation.currentIndex = navigation.count - 1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/VenuePage.qml"))
      }
      else if(activeTitle === "Tracks") {
        navigation.currentIndex = navigation.count - 1 // open more page
        navigation.currentPage.navigationStack.push(Qt.resolvedUrl("pages/TracksPage.qml"))
      }
    }
  }
}
