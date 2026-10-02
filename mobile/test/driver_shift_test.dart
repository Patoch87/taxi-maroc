import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_maroc/services/driver_shift.dart';

void main() {
  test('compte une personne de plus à chaque prise en charge, une de moins à chaque dépose', () {
    final shift = DriverShift(capacity: 3);
    shift.accept(ShiftRider(name: 'Amina', pickupIdx: 10, dropIdx: 50, fare: 12));
    shift.accept(ShiftRider(name: 'Karim', pickupIdx: 20, dropIdx: 40, fare: 9));
    expect(shift.onBoard, 0);
    expect(shift.freeSeats, 1); // deux places promises

    shift.advance(10);
    expect(shift.onBoard, 1);
    shift.advance(20);
    expect(shift.onBoard, 2);
    expect(shift.passengersToday, 2);

    final r = shift.advance(40);
    expect(r.dropped.map((x) => x.name), ['Karim']);
    expect(shift.onBoard, 1);
    expect(shift.earningsToday, 9);

    shift.advance(50);
    expect(shift.onBoard, 0);
    expect(shift.ridesToday, 2);
    expect(shift.earningsToday, 21);
  });

  test('passagers pris dans la rue et taxi complet', () {
    final shift = DriverShift(capacity: 3);
    expect(shift.addHail(), isTrue);
    expect(shift.addHail(), isTrue);
    shift.accept(ShiftRider(name: 'Salma', pickupIdx: 5, dropIdx: 9, fare: 8));
    expect(shift.isFull, isTrue);
    expect(shift.addHail(), isFalse);
    expect(shift.canAccept(1), isFalse);
    expect(shift.onBoard, 2);
    shift.advance(5);
    expect(shift.onBoard, 3);
    expect(shift.passengersToday, 3);
    expect(shift.removeHail(), isTrue);
    expect(shift.onBoard, 2);
  });

  test('grand taxi : 6 places, réservation de 2 places', () {
    final shift = DriverShift(capacity: 6);
    shift.accept(ShiftRider(name: 'Omar', pickupIdx: 1, dropIdx: 3, fare: 24, seats: 2));
    shift.advance(1);
    expect(shift.onBoard, 2);
    expect(shift.freeSeats, 4);
    expect(shift.nextStops().single.pickup, isFalse);
  });
}
