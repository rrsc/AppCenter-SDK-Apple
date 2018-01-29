import XCTest

class AppCenterUITests: XCTestCase {
  private var app : XCUIApplication?;
  private let AnalyticsCellIndex : UInt = 0;

  private let kDidSentEventText : String = "Sent event occurred";
  private let kDidFailedToSendEventText : String = "Failed to send event occurred";
  private let kDidSendingEventText : String = "Sending event occurred";

  override func setUp() {
    super.setUp()

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    app = XCUIApplication();
    app?.launch();
    guard let `app` = app else {
      return;
    }

    // Enable SDK (we need it in case SDK was disabled by the test, which then failed and didn't enabled SDK back).
    let appCenterButton : XCUIElement = app.switches["Set Enabled"];
    if (!appCenterButton.boolValue) {
      appCenterButton.tap();
    }
  }

  func testEnableDisableSDK() {
    guard let `app` = app else {
      return;
    }
    let appCenterButton : XCUIElement = app.switches["Set Enabled"];

    // SDK should be enabled.
    XCTAssertTrue(appCenterButton.boolValue);

    // Disable SDK.
    appCenterButton.tap();

    // All services should be disabled.
    // Analytics.
    app.tables["App Center"].staticTexts["Analytics"].tap();
    XCTAssertFalse(app.tables["Analytics"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();

    // Crashes.
    app.tables["App Center"].staticTexts["Crashes"].tap();
    XCTAssertFalse(app.tables["Crashes"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();

    // Distribute.
    app.tables["App Center"].staticTexts["Distribute"].tap();
    XCTAssertFalse( app.tables["Distribute"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();
    
    // Push.
    app.tables["App Center"].staticTexts["Push"].tap();
    XCTAssertFalse(app.tables["Push"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();

    // Enable SDK.
    appCenterButton.tap();

    // All services should be enabled.
    // Analytics.
    app.tables["App Center"].staticTexts["Analytics"].tap();
    XCTAssertTrue(app.tables["Analytics"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();

    // Crashes.
    app.tables["App Center"].staticTexts["Crashes"].tap();
    XCTAssertTrue(app.tables["Crashes"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();

    // Distribute.
    app.tables["App Center"].staticTexts["Distribute"].tap();
    XCTAssertTrue(app.tables["Distribute"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();
    
    // Push.
    app.tables["App Center"].staticTexts["Push"].tap();
    XCTAssertTrue(app.tables["Push"].switches["Set Enabled"].boolValue);
    app.buttons["App Center"].tap();
  }

  func testMiscellaneousInfo() {
    guard let `app` = app else {
      return;
    }

    // Go to device info page.
    app.tables["App Center"].staticTexts["Device Info"].tap();

    // Check device info. Device info shouldn't contain an empty info.
    for cellIndex in 0..<app.cells.count {
      let cell : XCUIElement = app.cells.element(boundBy: cellIndex);
      let deviceInfo : String = cell.staticTexts.element(boundBy: 1).label;
      XCTAssertNotNil(deviceInfo);
    }
    app.buttons["App Center"].tap();

    // Check install id.
    let installIdCell : XCUIElement = app.tables["App Center"].cell(containing: "Install ID");
    let installId : String = installIdCell.staticTexts.element(boundBy: 1).label;
    XCTAssertNotNil(UUID(uuidString: installId));

    // Check app secret.
    let appSecretCell : XCUIElement = app.tables["App Center"].cell(containing: "App Secret");
    let appSecret : String = appSecretCell.staticTexts.element(boundBy: 1).label;
    XCTAssertNotNil(UUID(uuidString: appSecret));

    // Check log url.
    let logUrlCell : XCUIElement = app.tables["App Center"].cell(containing: "Log URL");
    let logUrl : String = logUrlCell.staticTexts.element(boundBy: 1).label;
    XCTAssertNotNil(URL(string: logUrl));
  }
}
