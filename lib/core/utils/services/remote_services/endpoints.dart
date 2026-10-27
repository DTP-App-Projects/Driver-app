class EndPoints {
  /// Production host. Override for staging/local builds with
  /// `--dart-define=BASE_URL=https://staging.example.com`.
  static const baseUrl = String.fromEnvironment("BASE_URL", defaultValue: "https://tacaml.com");

  /////////////////////////// Maps /////////////////////////////

  /// OpenStreetMap tiles. The OSM tile policy requires an identifying user
  /// agent, see [osmUserAgent].
  static const osmTileUrl = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
  static const osmUserAgent = "com.dtp.driver";

  /// OSRM driving router on OpenStreetMap data. The public demo server is fair
  /// use only; point this at a self hosted OSRM for production traffic.
  static const osrmRouteUrl = "https://router.project-osrm.org/route/v1/driving";

  static const _v1 = "/api";
  static const _v2 = "/api/v2";

  /////////////////////////// 00 · Session & Auth /////////////////////////////
  static const deviceToken = "$_v1/auth/device_token";
  static const login = "$_v1/auth/login";
  static const updateBasicProfile = "$_v1/auth/profile";
  static const changePassword = "$_v1/auth/password";
  static const forgotPassword = "$_v1/auth/password/forgot";
  static const verifyResetCode = "$_v1/auth/password/verify_code";
  static const resetPassword = "$_v1/auth/password/reset";

  /////////////////////////// 02 · Driver Profile & Vehicle /////////////////////////////
  static const driverProfile = "$_v2/driver/profile";
  static const availableVehicles = "$_v2/driver/vehicles/available";
  static const assignVehicle = "$_v2/driver/vehicle";
  static const acceptTerms = "$_v2/driver/terms/accept";
  static const setLanguage = "$_v2/driver/language";

  /////////////////////////// 03 · Today's Route /////////////////////////////
  static const todayRoute = "$_v2/driver/today_route";
  static const routeHistory = "$_v2/driver/history";
  static const endOfDaySummary = "$_v2/driver/end_of_day_summary";

  static String startRoute(int routeId) => "$_v2/driver/routes/$routeId/start";

  static String completeRoute(int routeId) => "$_v2/driver/routes/$routeId/complete";

  /////////////////////////// 04 · Stop Execution /////////////////////////////
  static String stopEnRoute(int stopId) => "$_v2/driver/stops/$stopId/en_route";

  static String stopArrive(int stopId) => "$_v2/driver/stops/$stopId/arrive";

  static String stopPickup(int stopId) => "$_v2/driver/stops/$stopId/pickup";

  static String stopDeliver(int stopId) => "$_v2/driver/stops/$stopId/deliver";

  static String stopReturn(int stopId) => "$_v2/driver/stops/$stopId/return";

  static String stopSkip(int stopId) => "$_v2/driver/stops/$stopId/skip";

  static String stopReceiptStatus(int stopId) => "$_v2/driver/stops/$stopId/receipt_status";

  /////////////////////////// 05 · Receiver OTP /////////////////////////////
  static String otpResend(int stopId) => "$_v2/driver/stops/$stopId/otp/resend";

  static String otpVerify(int stopId) => "$_v2/driver/stops/$stopId/otp/verify";

  static String handoffVerify(int stopId) => "$_v2/driver/stops/$stopId/handoff/verify";

  /////////////////////////// 06 · Barcode, Seals & Rejections /////////////////////////////
  static String barcodeVerify(int stopId) => "$_v2/driver/stops/$stopId/barcode/verify";

  static String stopSeals(int stopId) => "$_v2/driver/stops/$stopId/seals";

  static String partialReject(int stopId) => "$_v2/driver/stops/$stopId/partial_reject";

  /////////////////////////// 07 · Proofs & File Upload /////////////////////////////
  static const uploads = "$_v2/driver/uploads";

  static String stopProof(int stopId) => "$_v2/driver/stops/$stopId/proof";

  /////////////////////////// 08 · Live Location /////////////////////////////
  static const location = "$_v2/driver/location";

  /// Firebase custom token + Realtime Database node for live tracking.
  static const driverLive = "$_v2/driver/live";

  /////////////////////////// 09 · Incidents /////////////////////////////
  static const reportIncident = "$_v2/driver/incidents";

  static String incidentAcknowledge(int incidentId) => "$_v2/incidents/$incidentId/acknowledge";

  static String incidentInvestigate(int incidentId) => "$_v2/incidents/$incidentId/investigate";

  static String incidentResolve(int incidentId) => "$_v2/incidents/$incidentId/resolve";

  static String incidentReopen(int incidentId) => "$_v2/incidents/$incidentId/reopen";

  static String incidentAge(int incidentId) => "$_v2/incidents/$incidentId/age";

  /////////////////////////// 10 · Notifications & Push /////////////////////////////
  static const notifications = "$_v2/driver/notifications";
  static const notificationsReadAll = "$_v2/driver/notifications/read_all";

  static String notificationRead(int notificationId) => "$_v2/driver/notifications/$notificationId/read";

  static const pushRegister = "$_v2/push/register";
  static const pushUnregister = "$_v2/push/unregister";

  /////////////////////////// 11 · Earnings & Performance /////////////////////////////
  static const earnings = "$_v2/driver/earnings";
  static const performance = "$_v2/driver/performance";

  /////////////////////////// 12 · Training & Certification /////////////////////////////
  static const trainingCurriculum = "$_v2/driver/training/curriculum";
  static const trainingCertificate = "$_v2/driver/training/certificate";

  static String trainingModule(int moduleId) => "$_v2/driver/training/modules/$moduleId";

  static String trainingModuleStart(int moduleId) => "$_v2/driver/training/modules/$moduleId/start";

  static String trainingModuleSubmit(int moduleId) => "$_v2/driver/training/modules/$moduleId/submit";

  /////////////////////////// 13 · Offline Sync /////////////////////////////
  static const syncBatch = "$_v2/driver/sync/batch";

  /////////////////////////// 15 · Van Sales /////////////////////////////
  static const vanTrip = "$_v2/driver/van/trip";

  static String vanTripLoad(int tripId) => "$_v2/driver/van/trips/$tripId/load";

  static String vanTripSales(int tripId) => "$_v2/driver/van/trips/$tripId/sales";

  static String vanTripTraders(int tripId) => "$_v2/driver/van/trips/$tripId/traders";

  static String vanTripDeliveries(int tripId) => "$_v2/driver/van/trips/$tripId/deliveries";

  static String vanTripReturn(int tripId) => "$_v2/driver/van/trips/$tripId/return";

  /////////////////////////// 14 · App Content & Account /////////////////////////////
  static const countries = "$_v1/countries";
  static const abouts = "$_v1/abouts";
  static const terms = "$_v1/terms";
  static const support = "$_v1/support";
  static const accountDeletionRequest = "$_v2/account/deletion_request";
}
