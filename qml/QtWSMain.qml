import VPlayApps 1.0
import QtQuick 2.0
import VPlay 2.0 // for game network
import VPlayPlugins 1.0
import "pages"
import "common"

App {
  id: app
  // add your V-Play license key with activated One Signal, Local Notifications, Facebook and Amplitude plugins here
  // licenseKey: "<add your license key>"

  property color secondaryTintColor: "#09102b"


  onInitTheme: {
    if(system.desktopPlatform)
      Theme.platform = "android"

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

  // local notifications (not within loader item to deactivate notifications within V-Play Demo Launcher app)
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
        NativeDialog.confirm("The conference starts soon!", "Thanks for using our app, we wish you a great Qt World Summit 2016!", function(){}, false)
      }
    }
  }

  // loads and holds actual app content
  QtWSLoaderItem { id: loaderItem }
}
