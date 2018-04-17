import VPlayApps 1.0
import QtQuick 2.0
import VPlay 2.0 // for game network
import VPlayPlugins 1.0 // keep it for qmldependency checks so all plugins are deployed
import "pages"
import "common"

App {
  id: app
  licenseKey: AppSettings.licenseKey

  property color secondaryTintColor: "#09102b"

  onInitTheme: {
    if(system.desktopPlatform)
      Theme.platform = "ios"

    // default theme setup
    Theme.colors.tintColor = "#41cd52"
    Theme.navigationBar.backgroundColor = Qt.binding(function() { return Theme.isAndroid ? app.secondaryTintColor : "#f8f8f8" })

    // tab bar
    Theme.tabBar.backgroundColor = Qt.binding(function() { return Theme.isAndroid ? app.secondaryTintColor : "#f8f8f8" })
    Theme.tabBar.markerColor = Qt.binding(function() { return Theme.tintColor })
    Theme.tabBar.titleColor = Qt.binding(function() { return Theme.tintColor })
    Theme.tabBar.titleOffColor = Qt.binding(function() { return Theme.secondaryTextColor })

    // status bar
    Theme.colors.statusBarStyle = Qt.binding(function() { return Theme.isAndroid ? Theme.colors.statusBarStyleWhite : Theme.colors.statusBarStyleBlack })
  }

  // handle Android back button (show dialog before closing application)
  onBackButtonPressedGlobally: {
    // only handle if on main page of app (back button jumps to main page otherwise)
    if(loaderItem.navigation && loaderItem.navigation.currentIndex !== 0)
      return

    // only handle if on first page of navigation stack (back button pops page otherwise)
    if(loaderItem.navigation && loaderItem.navigation.currentNavigationItem.navigationStack.depth !== 1)
      return

    // do not handle if navigation drawer is open (back button closes drawer in this case)
    if(loaderItem.navigation.drawer.isOpen)
      return

    // show confirmation dialog before quitting
    NativeDialog.confirm(qsTr("Really quit this app?"),"",function(ok){
      if(ok)
        Qt.quit()
    }, true)

    event.accepted = true // prevent immediate quit (back button default action)
  }

  // local notifications
  NotificationManager {
    id: notificationManager
    // display alert for upcoming sessions
    onNotificationFired: {
      if(notificationId >= 0) {
        // session reminder
        if(DataModel.loaded && DataModel.talks && DataModel.talks[notificationId]) {
          var talk = DataModel.talks[notificationId]
          var text = talk["title"]+" starts "+talk.start+" at "+talk["room"]+"."
          var title = "Session Reminder"
          NativeDialog.confirm(title, text, function(){}, false)
        }
      }
      else {
        // default notification
        NativeDialog.confirm("The conference starts soon!", "Thanks for using our app, we wish you a great Qt World Summit 2017!", function(){}, false)
      }
    }
  }

  // loads and holds actual app content
  QtWSLoaderItem { id: loaderItem }
}
