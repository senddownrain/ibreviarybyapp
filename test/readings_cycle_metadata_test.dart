import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/readings_cycle_metadata.dart';

void main() {
  test('cycle appears once for automatic and manual selections', () {
    expect(
      readingsCycleMetadata(cycle: 'B', manualGroup: false, manualCycle: false),
      'Цыкл B',
    );
    expect(
      readingsCycleMetadata(cycle: 'B', manualGroup: false, manualCycle: true),
      'Цыкл B · зменены',
    );
    expect(
      readingsCycleMetadata(cycle: null, manualGroup: true, manualCycle: false),
      'Набор чытанняў · зменены',
    );
    expect(
      readingsCycleMetadata(cycle: 'B', manualGroup: true, manualCycle: true),
      'Набор і цыкл B · зменены',
    );
    expect(
      readingsCycleMetadata(
        cycle: null,
        manualGroup: false,
        manualCycle: false,
      ),
      isNull,
    );
  });
}
