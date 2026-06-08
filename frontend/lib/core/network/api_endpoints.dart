import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static late final String baseUrl;

  static void init() {
    baseUrl = dotenv.env['BACKEND_URL'] ?? '';
  }

  // Auth
  static const authGoogle = '/api/auth/google';
  static const authApple = '/api/auth/apple';
  static const authLogout = '/api/auth/logout';

  // Token
  static const tokenRotate = '/api/token/';

  // User
  static const userMe = '/api/user/me';
  static const userBalances = '/api/user/balances';
  static const userUpdate = '/api/user/update';

  // Transactions
  static const transaction = '/api/transaction';
  static String transactionById(dynamic id) => '/api/transaction/$id';
  static const transactionReceipt = '/api/transaction/receipt';

  // Categories
  static const category = '/api/category';

  // Currency
  static const currency = '/api/currency';

  // Statistics
  static const statisticsPie = '/api/statistics/pie';
  static const statisticsMonthly = '/api/statistics/monthly';
  static const statisticsTotalSpent = '/api/statistics/total-spent';
  static const statisticsAverage = '/api/statistics/average';

  // Savings
  static const saving = '/api/saving';
  static String savingById(dynamic id) => '/api/saving/$id';

  // Wallets
  static const wallet = '/api/wallet';
  static String walletById(dynamic id) => '/api/wallet/$id';
  static String walletJoin(dynamic id) => '/api/wallet/$id/join';
  static const walletJoinByCode = '/api/wallet/join';
  static String walletLeave(dynamic id) => '/api/wallet/$id/leave';
  static String walletSettle(dynamic id) => '/api/wallet/$id/settle';
  static String walletBalances(dynamic id) => '/api/wallet/$id/balances';
  static String walletExpense(dynamic id) => '/api/wallet/$id/expense';
}
