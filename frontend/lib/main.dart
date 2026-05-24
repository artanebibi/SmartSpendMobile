import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartspend/core/network/api_endpoints.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/signin_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/transactions/models/transaction_model.dart';
import 'features/transactions/providers/transaction_provider.dart';
import 'features/transactions/screens/add_transaction_screen.dart';
import 'features/transactions/screens/scan_receipt_screen.dart';
import 'features/transactions/screens/transaction_detail_screen.dart';
import 'features/transactions/screens/transactions_screen.dart';
import 'features/stats/providers/stats_provider.dart';
import 'features/stats/screens/stats_screen.dart';
import 'features/savings/providers/savings_provider.dart';
import 'features/savings/screens/create_goal_screen.dart';
import 'features/savings/screens/goal_detail_screen.dart';
import 'features/savings/screens/savings_screen.dart';
import 'features/wallets/providers/wallet_provider.dart';
import 'features/wallets/screens/add_expense_screen.dart';
import 'features/wallets/screens/create_wallet_screen.dart';
import 'features/wallets/screens/settle_screen.dart';
import 'features/wallets/screens/wallet_detail_screen.dart';
import 'features/wallets/screens/wallet_list_screen.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/screens/profile_screen.dart';
import 'shared/widgets/bottom_tab_bar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  ApiEndpoints.init();

  runApp(const SmartSpendApp());
}

class SmartSpendApp extends StatelessWidget {
  const SmartSpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => SavingsProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: MaterialApp.router(
        title: 'SmartSpend',
        theme: AppTheme.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),

    ShellRoute(
      builder: (context, state, child) => AppBottomTabBar(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/home/dashboard',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/home/transactions',
          builder: (_, __) => const TransactionsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => AddTransactionScreen(
                initial: state.extra as TransactionModel?,
              ),
            ),
            GoRoute(
              path: 'scan',
              builder: (_, __) => const ScanReceiptScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => TransactionDetailScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/home/stats',
          builder: (_, __) => const StatsScreen(),
        ),
        GoRoute(
          path: '/home/savings',
          builder: (_, __) => const SavingsScreen(),
          routes: [
            GoRoute(
              path: 'create',
              builder: (_, __) => const CreateGoalScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => GoalDetailScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/home/wallets',
          builder: (_, __) => const WalletListScreen(),
          routes: [
            GoRoute(
              path: 'create',
              builder: (_, __) => const CreateWalletScreen(),
            ),
            GoRoute(
              path: 'settle',
              builder: (_, __) => const SettleScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => WalletDetailScreen(
                walletId: state.pathParameters['id'] ?? '',
              ),
              routes: [
                GoRoute(
                  path: 'add-expense',
                  builder: (_, state) => AddExpenseScreen(
                    walletId: state.pathParameters['id'] ?? '',
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/home/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
