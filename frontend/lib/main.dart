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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  ApiEndpoints.init();

  final authProvider = AuthProvider();
  // Fire-and-forget: sets isInitialized when done, which triggers router redirect
  authProvider.tryRestoreSession();

  runApp(SmartSpendApp(authProvider: authProvider));
}

class SmartSpendApp extends StatefulWidget {
  const SmartSpendApp({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  State<SmartSpendApp> createState() => _SmartSpendAppState();
}

class _SmartSpendAppState extends State<SmartSpendApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter(widget.authProvider);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
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

GoRouter _buildRouter(AuthProvider auth) => GoRouter(
      initialLocation: '/splash',
      refreshListenable: auth,
      redirect: (context, state) {
        final loc = state.matchedLocation;

        // Show splash until session restore completes
        if (!auth.isInitialized) {
          return loc == '/splash' ? null : '/splash';
        }

        // Once initialized, leave splash toward the right destination
        if (loc == '/splash') {
          return auth.isAuthenticated ? '/home/dashboard' : '/';
        }

        final isAuthRoute = loc == '/' || loc == '/signin';

        if (auth.isAuthenticated && isAuthRoute) {
          return '/home/dashboard';
        }

        if (!auth.isAuthenticated && !isAuthRoute) {
          return '/signin';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => const _SplashScreen(),
        ),
        GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),

        ShellRoute(
          builder: (context, state, child) => AppBottomTabBar(
            location: state.uri.toString(),
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/home/dashboard',
              builder: (_, _) => const HomeScreen(),
            ),
            GoRoute(
              path: '/home/transactions',
              builder: (_, _) => const TransactionsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => AddTransactionScreen(
                    initial: state.extra as TransactionModel?,
                  ),
                ),
                GoRoute(
                  path: 'scan',
                  builder: (_, _) => const ScanReceiptScreen(),
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
              builder: (_, _) => const StatsScreen(),
            ),
            GoRoute(
              path: '/home/savings',
              builder: (_, _) => const SavingsScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (_, _) => const CreateGoalScreen(),
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
              builder: (_, _) => const WalletListScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (_, _) => const CreateWalletScreen(),
                ),
                GoRoute(
                  path: 'settle',
                  builder: (_, _) => const SettleScreen(),
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
              builder: (_, _) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    );

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
