#include <QApplication>
#include <VPApplication>

#include <QQmlApplicationEngine>
#include "cpp/diskcachefactory.h"

int main(int argc, char *argv[])
{
  QApplication app(argc, argv);
  VPApplication vplay;

  // Use platform-specific fonts instead of V-Play's default font
  vplay.setPreservePlatformFonts(true);

  QQmlApplicationEngine engine;
  vplay.initialize(&engine);

  // use this during development
  // for PUBLISHING, use the entry point below
  vplay.setMainQmlFileName(QStringLiteral("qml/QtWSMain.qml"));

  // use this instead of the above call to avoid deployment of the qml files and compile them into the binary with qt's resource system qrc
  // this is the preferred deployment option for publishing games to the app stores, because then your qml files and js files are protected
  // to avoid deployment of your qml files and images, also comment the DEPLOYMENTFOLDERS command in the .pro file
  // also see the .pro file for more details
  // vplay.setMainQmlFileName(QStringLiteral("qrc:/qml/QtWSMain.qml"));

  // 10MB cache for network data (chris bartsch style)
  engine.setNetworkAccessManagerFactory(new DiskCacheFactory(1024 * 1024 * 10));

  engine.load(QUrl(vplay.mainQmlFileName()));

  return app.exec();
}
