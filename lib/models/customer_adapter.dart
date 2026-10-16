import 'package:hive/hive.dart';
import 'customer.dart';

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 0;

  @override
  Customer read(BinaryReader reader) {
    return Customer(
      name: reader.read(),
      nickname: reader.read(),
      phone: reader.read(),
      isSynced: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer.write(obj.name);
    writer.write(obj.nickname);
    writer.write(obj.phone);
    writer.writeBool(obj.isSynced);
  }
}
