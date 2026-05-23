class ApiEndpoints {
  ApiEndpoints._();

  static const baseUrl = 'https://cef8-185-100-244-20.ngrok-free.app';

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
}
