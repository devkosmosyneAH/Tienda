part of '../../View/Cash/cash_view.dart';

class CashCurrentTab extends StatelessWidget {
  const CashCurrentTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CashController>(
      builder: (context, controller, _) {
        if (controller.isLoading && controller.stores.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = controller.summary ?? {};
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 20,
                ),
                children: [
                  _CashSectionHeader(
                    controller: controller,
                    onStoreChanged: (value) {
                      if (value != null) controller.selectStore(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (controller.hasOpenSession)
                    isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 360,
                                child: _CashStatusCard(
                                  controller: controller,
                                  summary: summary,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _CashKpiGrid(summary: summary),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _CashStatusCard(
                                controller: controller,
                                summary: summary,
                              ),
                              const SizedBox(height: 16),
                              _CashKpiGrid(summary: summary),
                            ],
                          )
                  else
                    _CashStatusCard(controller: controller, summary: summary),
                  if (controller.hasOpenSession) ...[
                    const SizedBox(height: 20),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MovementsCard(
                              movements: controller.movements,
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 320,
                            child: _CashSummaryCard(
                              summary: summary,
                              breakdown: controller.openingBreakdown,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _MovementsCard(movements: controller.movements),
                      const SizedBox(height: 16),
                      _CashSummaryCard(
                        summary: summary,
                        breakdown: controller.openingBreakdown,
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}
