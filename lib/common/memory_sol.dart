
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

import 'messages.dart';

class MemorySol {
    // sin http://
    static const String APP_HOST_NAME_WITHOUT_HTTP_TEST ='192.168.188.105:3000';
    static const String APP_HOST_NAME_WITHOUT_HTTP_PRODUCTION ='app1.masverdecde.com';
    static String APP_HOST_NAME_WITHOUT_HTTP ='147.93.66.125:3000';
    //static String APP_HOST_NAME_WITHOUT_HTTP ='192.168.188.105';
    //con http://
    static const String APP_HOST_WITH_HTTP_TEST ='http://192.168.188.105:3000';
    static const String APP_HOST_WITH_HTTP_PRODUCTION ='https://app1.masverdecde.com';
    static String APP_HOST_WITH_HTTP ='http://147.93.66.125:3000';
    //static String APP_HOST_WITH_HTTP ='http://192.168.188.105:3000';
    static bool isDeliveredOrder = false;
    static DateTime deliveryDateLocal = MemorySol.getDateTimeNowLocal();
    static DateTime orderCreatePageOpenedAtDateTimeLocal = MemorySol.getDateTimeNowLocal();
    static String WEB_URL='https://app.solexpresspy.com/';
    static int PAGE_REFRESH_TIME_IN_MINUTES = 5;
    //static Map<String,String>  headers  ={};
    static bool TESTING_MODE = true;
    static bool widescreen = false;
    static int SAVED_CLIENT_LIST_EXPIRE_TIME_IN_HOURS =2 ;
    static List<Color> colorsAppBarOdd =[Colors.cyan.shade300,Colors.purple.shade300];
    static List<Color> colorsAppBarEven =[Colors.purple.shade300,Colors.cyan.shade300];
    static double minimumWideScreenWidth = 700;
    static double minimumWideScreenColumWidth = 380;
    static int TIMEZONE_OFFSET = -3;
    static int DURATION_TRANSITION_SECUNDS = 2;
    static int DURATION_TRANSITION_MILLI_SECUNDS = 500;
    static int DURATION_TRANSITION_SHORT_SECUNDS = 1;
    static bool SAVE_USER_SESSION = true;
    static int FIREBASE_NOTIFICATION_TOKEN_EXPIRES_DAYS = 29;
    static double VALUE_OF_METER_DELIVERY_BOY_IS_CLOSED_TO_CLIENT = 200.0;
    static bool CHECK__DELIVERY_BOY_IS_CLOSED_TO_CLIENT = true;
    static bool VAT_INCLUDED_MODE = true;
    static String COMPANY_NAME ='SOL EXPRESS S.A.';


    static final List<String> keyToRemoveAtSignOut =[];


    static ThemeData THEME = ThemeData(
        scaffoldBackgroundColor: Colors.lightGreen.shade300,
        highlightColor: const Color(0xFF6FD0B9),
        canvasColor: const Color(0xFFFDF5EC),
        bottomSheetTheme:BottomSheetThemeData(backgroundColor: Colors.amber[200]),
        textTheme: TextTheme(
        headlineSmall: ThemeData.light()
            .textTheme
            .headlineSmall!
            .copyWith(color: const Color(0xFF6FD0B9)),
        ),
        iconTheme: IconThemeData(
            color: Colors.grey[600],
        ),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF6FD0B9),
            centerTitle: false,
            foregroundColor: Colors.white,
            actionsIconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
                backgroundColor: WidgetStateColor.resolveWith(
                (states) => const Color(0xFFE8C855)),
                foregroundColor: WidgetStateColor.resolveWith(
                    (states) => Colors.white,
                ),
            ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: ButtonStyle(
                foregroundColor: WidgetStateColor.resolveWith(
                (states) => const Color(0xFFBC764A),
                ),
                side: WidgetStateBorderSide.resolveWith(
                (states) => const BorderSide(color: Color(0xFFBC764A))),
            ),
        ),
        textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
                foregroundColor: WidgetStateColor.resolveWith(
                (states) => const Color(0xFFBC764A),
            ),
            ),
        ),
        iconButtonTheme: IconButtonThemeData(
            style: ButtonStyle(
                foregroundColor: WidgetStateColor.resolveWith(
                (states) => const Color(0xFFBC764A),
                ),
            ),
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
            surface: const Color(0xFFFDF5EC), //backgroud color
            primary: const Color(0xFFD0996F),
        ),
    );
    static void functionNotEnabledYet(){
        Get.snackbar(Messages.ERROR, Messages.FUNTION_NOT_ENABLED_YED);
    }
    //static Product currentProduct = Product();
    static final String KEY_APP_HOST_WITH_HTTP ='app_host_with_http';
    static final String KEY_HOST ='host';
    static final String KEY_IS_USING_LOCAL_HOST ='is_using_local_host';
    static final String KEY_APP_HOST_NAME_WITHOUT_HTTP ='app_host_name_without_http';
    static final String KEY_SHOPPING_BAG ='shopping_bag';
    static final String KEY_IS_DEBIT_TRANSACTION ='is_debit_transaction';
    static final String KEY_IS_DELIVERED_ORDER ='is_delivered_order';
    static final String KEY_DELIVERY_DATE ='delivery_date';
    static final String KEY_CURRENT_PROCUCT ='current_product';
    static final String KEY_DO_LOGIN ='do_login';
    static final String KEY_AUTO_LOGIN ='auto_login';
    static final String KEY_RETURN_ITEM_LIST ='shopping_bag';
    static final String KEY_NEW_ORDER ='new_order';
    static final String KEY_INVOICE_SAVED ='invoice_saved';
    static final String KEY_ORDERS ='orders';
    static final String KEY_ORDER ='order';
    static final String KEY_RETURN_ORDER ='return_order';
    static final String KEY_LAST_ORDER ='last_order';
    static final String KEY_ADDRESS ='address';
    static final String KEY_DELIVERY ='delivery';
    static final String KEY_USER_HOME ='user_home';
    static final String KEY_USER ='user';
    static final String KEY_PAYMENT ='payment';
    static final String KEY_PAYMENT_TYPE ='payment_type';
    static final String KEY_CLIENT_SOCIETY ='client_society';
    static final String KEY_CLIENT_CATEGORIES_LIST ='client_categories';
    static final String KEY_CLIENT_CATEGORIES_LIST_CREATED_AT ='client_categories_created_at';
    static final String KEY_CLIENT_PRODUCTS_LIST ='client_products_list';
    static final String KEY_CLIENT_PRODUCTS_LIST_CREATED_AT ='client_products_list_created_at';
    static final String KEY_SOCIETIES_LIST ='societies_list';
    static final String KEY_NOTIFICATION_TOKEN ='notification_token';
    static final String KEY_PLACE_OF_DELIVERY ='place_of_delivery';

    static String ROUTE_WEB_VIEW_PAGE ='/web/view';
    static String ROUTE_EXCEL_PAGE ='/excel';
    static String ROUTE_LOGIN_PAGE ='/'; // login_page
    static String ROUTE_REGISTER_PAGE ='/register';
    static String ROUTE_HOME_PAGE ='/home';
    static String ROUTE_ROLES_PAGE = '/roles';
    static String ROUTE_IMAGE_TOOL_PAGE = '/utils/image/tool';

    //static String NODEJS_ROUTE_='/api/';
    static String IMAGE_LOGO ='assets/img/logo_name.jpg';
    static String IMAGE_WHATSAPP ='assets/img/whatsapp.png';
    static String IMAGE_SHEETS ='assets/img/sheets.png';
    static String IMAGE_SPLASH_SCREEN = 'assets/img/splash_screen.jpg';
    static String IMAGE_LOGIN_PAGE_ICON = 'assets/img/login_page_icon.png';

    static Future<bool> checkExternalMediaPermission() async {

        late PermissionStatus status;
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
        if (info.version.sdkInt >= 33) {
            // android 13+
            status = await Permission.manageExternalStorage.request();
            print('android 33+ storagey $status');
            status = await Permission.videos.request();
            print('android 33+ video $status');
        } else if (info.version.sdkInt >= 30) {
            // android 11+ `storage.request()` still work on 11
            //status = await Permission.storage.request();  // dialog

            status = await Permission.manageExternalStorage.request(); // full screen
            print('android 30+ video $status');
        } else {
            status = await Permission.storage.request();
        }
        print('status $status');
        if(status == PermissionStatus.permanentlyDenied){
            openAppSettings();
            return false;
        } else if(status == PermissionStatus.denied){
            return false;
        } else if(status == PermissionStatus.granted){
            return true;
        }
        return false;
    }

  static  DateTime getDateTimeNowLocal(){
        return DateTime.now().add(Duration(hours: TIMEZONE_OFFSET));
  }



//-----------------------------2025-06-23


  static String ROUTE_THERMAL_PRINTER_PAGE='/printer/thermal';

  static const String KEY_LIST_TO_PRINT = 'key_list_order_to_print';
  static const String KEY_LIST_OF_WIFI_PRINTER = 'key_list_of_wifi_printer';

  static const String KEY_SCAN_DURATION ='key_scan_duration';
  static const String KEY_BACK_FROM_PRINTING_DURATION ='key_back_from_printing_duration';

  static const String KEY_POS_PRINT_DATA='key_pos_print_data';

  static const String KEY_LABEL_SIZE='key_label_size';
  static const String KEY_IMAGE_LOGO_BYTES='key_image_logo_bytes';

  static String KEY_TSPL_COMMAND='key_tspl_command';
  static String KEY_ZPL_COMMAND='key_zpl_command';





  static String getTodayCN(){
     DateTime now = DateTime.now();
      String day = '${now.day}${Messages.DAY_CN}';
      String month = '${now.month}${Messages.MONTH_CN}';
      String year = '${now.year}${Messages.YEAR_CN}';
      return '$year$month$day';
  }

  static String getToday() {
      DateTime now = DateTime.now();
      String day = '${now.day}/';
      String month = '${now.month}/';
      return '$day$month${now.year}';
  }

  static Future<File>  getLogoFile() async {
      final documentDirectory = await getApplicationDocumentsDirectory();
      final file = File(path.join(documentDirectory.path, 'temp_image.png'));
      return file ;
  }

















}
