import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_logger.dart';

class LoggedScreen extends StatefulWidget {
  const LoggedScreen({
    super.key,
    required this.screenName,
    required this.child,
    this.data,
  });

  final String screenName;
  final Widget child;
  final Map<String, dynamic>? data;

  @override
  State<LoggedScreen> createState() => _LoggedScreenState();
}

class _LoggedScreenState extends State<LoggedScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(AppLogger.instance.screenMounted(widget.screenName, data: widget.data));
  }

  @override
  void dispose() {
    unawaited(AppLogger.instance.screenDisposed(widget.screenName, data: widget.data));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
