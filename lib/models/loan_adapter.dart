import 'package:hive/hive.dart';
import 'loan.dart';

class LoanItemAdapter extends TypeAdapter<LoanItem> {
  @override
  final int typeId = 2;

  @override
  LoanItem read(BinaryReader reader) {
    return LoanItem(
      name: reader.readString(),
      unitPrice: reader.readDouble(),
      quantity: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, LoanItem obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.unitPrice);
    writer.writeDouble(obj.quantity);
  }
}

class LoanAdapter extends TypeAdapter<Loan> {
  @override
  final int typeId = 3;

  @override
  Loan read(BinaryReader reader) {
    final customerKey = reader.readInt();
    final title = reader.readString();
    final items = reader.readList().cast<LoanItem>();
    final dateTime = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final isSynced = reader.readBool();

    return Loan(
      customerKey: customerKey,
      title: title,
      items: items,
      dateTime: dateTime,
      isSynced: isSynced,
    );
  }

  @override
  void write(BinaryWriter writer, Loan obj) {
    writer.writeInt(obj.customerKey);
    writer.writeString(obj.title);
    writer.writeList(obj.items);
    writer.writeInt(obj.dateTime.millisecondsSinceEpoch);
    writer.writeBool(obj.isSynced);
  }
}
