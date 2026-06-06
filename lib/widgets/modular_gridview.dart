import 'package:aaram_bd/widgets/modular_listview.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/api_service.dart';


class ModularGridView extends StatelessWidget {
  final ApiService apiService;
  final int pageSize;
  final Widget Function(BuildContext, dynamic) itemBuilder;

  const ModularGridView({
    required this.apiService,
    required this.pageSize,
    required this.itemBuilder,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ModularListView(
      apiService: apiService,
      pageSize: pageSize,
      itemBuilder: itemBuilder,
      sortBy: 'recent',
    );
  }
}
