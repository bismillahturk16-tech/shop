import 'package:hive/hive.dart';
import 'payment.dart';

class PaymentAdapter extends TypeAdapter<Payment> {
  @override
  final int typeId = 1;

  @override
  Payment read(BinaryReader reader) {
    return Payment(
      customerKey: reader.read(),
      amount: reader.read(),
      description: reader.read(),
      dateTime: reader.read(),
      isSynced: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Payment obj) {
    writer.write(obj.customerKey);
    writer.write(obj.amount);
    writer.write(obj.description);
    writer.write(obj.dateTime);
    writer.writeBool(obj.isSynced);
  }
}
