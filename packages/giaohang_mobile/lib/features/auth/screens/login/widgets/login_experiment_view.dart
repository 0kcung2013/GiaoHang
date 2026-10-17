import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import 'login_experiment_form.dart';
import 'login_experiment_tokens.dart';
import 'login_experiment_visual.dart';

class LoginExperimentView extends StatefulWidget {
  const LoginExperimentView({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isBusy,
    required this.obscurePassword,
    required this.emailValidator,
    required this.passwordValidator,
    required this.onEmailSignIn,
    required this.onGoogleSignIn,
    required this.onTogglePassword,
    required this.onRegister,
    required this.onPasswordSubmitted,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isBusy;
  final bool obscurePassword;
  final String? errorMessage;
  final FormFieldValidator<String> emailValidator;
  final FormFieldValidator<String> passwordValidator;
  final VoidCallback onEmailSignIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onTogglePassword;
  final VoidCallback onRegister;
  final ValueChanged<String> onPasswordSubmitted;

  @override
  State<LoginExperimentView> createState() => _LoginExperimentViewState();
}

class _LoginExperimentViewState extends State<LoginExperimentView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  bool _motionConfigured = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _entranceController.value = 1;
    } else {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: LoginExperimentTokens.heroTop,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final compactVertical =
                  keyboardOpen ||
                  constraints.maxHeight < 720 ||
                  textScale > 1.3;
              final hideSecondaryActions =
                  keyboardOpen ||
                  constraints.maxHeight < 620 ||
                  textScale > 1.4;
              return isWide
                  ? _WideLoginLayout(
                      constraints: constraints,
                      entranceController: _entranceController,
                      form: _buildForm(
                        isWide: true,
                        compactVertical: compactVertical,
                        hideSecondaryActions: hideSecondaryActions,
                      ),
                    )
                  : _CompactLoginLayout(
                      constraints: constraints,
                      entranceController: _entranceController,
                      keyboardOpen: keyboardOpen,
                      textScale: textScale,
                      form: _buildForm(
                        isWide: false,
                        compactVertical: compactVertical,
                        hideSecondaryActions: hideSecondaryActions,
                      ),
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm({
    required bool isWide,
    required bool compactVertical,
    required bool hideSecondaryActions,
  }) {
    return LoginExperimentFormSurface(
      isWide: isWide,
      compactVertical: compactVertical,
      hideSecondaryActions: hideSecondaryActions,
      formKey: widget.formKey,
      emailController: widget.emailController,
      passwordController: widget.passwordController,
      isBusy: widget.isBusy,
      obscurePassword: widget.obscurePassword,
      errorMessage: widget.errorMessage,
      emailValidator: widget.emailValidator,
      passwordValidator: widget.passwordValidator,
      onEmailSignIn: widget.onEmailSignIn,
      onGoogleSignIn: widget.onGoogleSignIn,
      onTogglePassword: widget.onTogglePassword,
      onRegister: widget.onRegister,
      onPasswordSubmitted: widget.onPasswordSubmitted,
    );
  }
}

class _WideLoginLayout extends StatelessWidget {
  const _WideLoginLayout({
    required this.constraints,
    required this.entranceController,
    required this.form,
  });

  final BoxConstraints constraints;
  final AnimationController entranceController;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final panelHeight = (constraints.maxHeight - 64).clamp(480.0, 760.0);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Container(
            height: panelHeight,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: LoginExperimentTokens.surface,
              borderRadius: LoginExperimentTokens.desktopRadius,
              boxShadow: AppShadow.elevated,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: _EntranceTransition(
                    animation: entranceController,
                    begin: 0,
                    end: 0.72,
                    offset: const Offset(-0.025, 0),
                    child: LoginExperimentVisualPanel(
                      isWide: true,
                      height: panelHeight,
                    ),
                  ),
                ),
                Expanded(
                  flex: 9,
                  child: _EntranceTransition(
                    animation: entranceController,
                    begin: 0.16,
                    end: 1,
                    offset: const Offset(0.025, 0),
                    child: form,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactLoginLayout extends StatelessWidget {
  const _CompactLoginLayout({
    required this.constraints,
    required this.entranceController,
    required this.keyboardOpen,
    required this.textScale,
    required this.form,
  });

  final BoxConstraints constraints;
  final AnimationController entranceController;
  final bool keyboardOpen;
  final double textScale;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final availableHeight = constraints.maxHeight;
    final heroHeight = keyboardOpen
        ? (availableHeight * 0.28).clamp(96.0, 150.0)
        : textScale > 1.3
        ? (availableHeight * 0.25).clamp(130.0, 180.0)
        : availableHeight >= 760
        ? (availableHeight * 0.38).clamp(280.0, 310.0)
        : (availableHeight * 0.34).clamp(205.0, 250.0);
    final sheetTop = (heroHeight - 30).clamp(72.0, availableHeight - 260);

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _EntranceTransition(
              animation: entranceController,
              begin: 0,
              end: 0.72,
              offset: const Offset(0, -0.02),
              child: LoginExperimentVisualPanel(
                isWide: false,
                height: heroHeight,
              ),
            ),
          ),
          Positioned(
            top: sheetTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: _EntranceTransition(
              animation: entranceController,
              begin: 0.16,
              end: 1,
              offset: const Offset(0, 0.035),
              child: form,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntranceTransition extends StatelessWidget {
  const _EntranceTransition({
    required this.animation,
    required this.begin,
    required this.end,
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final double begin;
  final double end;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, end, curve: AppCurve.decelerate),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: offset,
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
