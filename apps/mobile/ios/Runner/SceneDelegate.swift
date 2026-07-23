import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url {
      handleOpenedURL(url)
    }
    if let response = connectionOptions.notificationResponse {
      (UIApplication.shared.delegate as? AppDelegate)?.handlePushNotification(
        userInfo: response.notification.request.content.userInfo
      )
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      handleOpenedURL(url)
    }
  }

  private func handleOpenedURL(_ url: URL) {
    (UIApplication.shared.delegate as? AppDelegate)?.handleIncomingGpx(url: url)
  }
}
