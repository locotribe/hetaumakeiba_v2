import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

// 3列目: 騎手・斤量・馬主セル
class JockeyProfileCell extends StatelessWidget {
  final PredictionHorseDetail horse;
  final String owner;

  const JockeyProfileCell({
    Key? key,
    required this.horse,
    required this.owner,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (horse.ownerImageLocalPath != null && horse.ownerImageLocalPath!.isNotEmpty)
            Image.file(File(horse.ownerImageLocalPath!), width: 22, height: 22, errorBuilder: (c, e, s) => const SizedBox(height: 22))
          else
            const SizedBox(height: 22),
          const SizedBox(height: 2),
          Text(
            owner,
            style: const TextStyle(fontSize: 6, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            '${(horse.previousJockey != null && horse.jockey != horse.previousJockey) ? '替 ' : ''}${horse.jockey}',
            style: TextStyle(
              fontSize: 10,
              color: (horse.previousJockey != null && horse.jockey != horse.previousJockey) ? Colors.orange.shade800 : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            horse.jockeyComboStats?.isFirstRide == true ? '初' : (horse.jockeyComboStats?.recordString ?? '--'),
            style: const TextStyle(fontSize: 9, color: Colors.blueGrey),
          ),
          const SizedBox(height: 2),
          Text('${horse.carriedWeight}kg', style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

// 4列目: 所属・調教師セル
class TrainerCell extends StatelessWidget {
  final PredictionHorseDetail horse;
  final Color backgroundColor;

  const TrainerCell({
    Key? key,
    required this.horse,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            horse.trainerAffiliation,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            horse.trainerName,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}