import Contacts
import ContactsUI
import Flutter
import SwiftUI
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase before plugin registration so firebase_core picks
    // up the configured app on first call from Dart.
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "ContactsAccessPlugin") {
      ContactsAccessPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Contacts permission details flutter_contacts doesn't expose: iOS 18's
/// "limited" access, Apple's picker for sharing more contacts with the
/// app, and a shortcut to the app's page in Settings.
///
/// Channel `kharchasplit/contacts_access`:
/// - `status` → "full" | "limited" | "denied" | "restricted" | "notDetermined"
/// - `addMoreContacts` → number of contacts the person added (iOS 18+)
/// - `pickContact` → {id, name, phones} from the system picker, which needs
///   no permission at all (nil when cancelled)
/// - `openSettings`
class ContactsAccessPlugin: NSObject, FlutterPlugin, CNContactPickerDelegate {
  private var pickResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "kharchasplit/contacts_access",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(ContactsAccessPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(Self.status())
    case "addMoreContacts":
      presentAccessPicker(result)
    case "pickContact":
      presentContactPicker(result)
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func status() -> String {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    if #available(iOS 18.0, *), status == .limited { return "limited" }
    switch status {
    case .authorized: return "full"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    default: return "denied"
    }
  }

  /// Shows Apple's ContactAccessPicker (SwiftUI only) from a clear
  /// hosting controller and reports how many contacts were added.
  private func presentAccessPicker(_ result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *) else {
      result(0)
      return
    }
    guard let top = Self.topViewController() else {
      result(0)
      return
    }
    var host: UIViewController?
    var finished = false
    let finish: (Int) -> Void = { count in
      guard !finished else { return }
      finished = true
      host?.dismiss(animated: false)
      result(count)
    }
    let controller = UIHostingController(rootView: AccessPickerHost(onDone: finish))
    controller.view.backgroundColor = .clear
    controller.modalPresentationStyle = .overFullScreen
    host = controller
    top.present(controller, animated: false)
  }

  /// The system contact picker runs out of process: the person can pick
  /// anyone, whatever the app's contacts permission.
  private func presentContactPicker(_ result: @escaping FlutterResult) {
    guard let top = Self.topViewController() else {
      result(nil)
      return
    }
    pickResult?(nil)
    pickResult = result
    let picker = CNContactPickerViewController()
    picker.delegate = self
    picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
    picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
    top.present(picker, animated: true)
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
    pickResult?([
      "id": contact.identifier,
      "name": name,
      "phones": contact.phoneNumbers.map { $0.value.stringValue },
    ])
    pickResult = nil
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    pickResult?(nil)
    pickResult = nil
  }

  static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

/// Invisible SwiftUI host for `.contactAccessPicker`. Done with the
/// identifiers the person shared; a cancel reports 0.
@available(iOS 18.0, *)
private struct AccessPickerHost: View {
  let onDone: (Int) -> Void
  @State private var shown = true

  var body: some View {
    Color.clear
      .contactAccessPicker(isPresented: $shown) { identifiers in
        onDone(identifiers.count)
      }
      .onChange(of: shown) { _, isShown in
        // Closing may come before the completion handler; give it a
        // moment so a real count wins over the cancel.
        if !isShown {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone(0) }
        }
      }
  }
}
