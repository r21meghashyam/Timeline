import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:timeline/timeline/timeline.dart';
import 'package:timeline/timeline/timeline_utils.dart';
import '../store.dart';

/// This class is used by the [TimelineRenderWidget] to render the ticks on the left side of the screen.
///
/// It has a single [paint()] method that's called within [TimelineRenderObject.paint()].
class Ticks {
  /// The following `const` variables are used to properly align, pad and layout the ticks
  /// on the left side of the timeline.
  static const double Margin = 20.0;
  static const double Width = 40.0;
  static const double LabelPadLeft = 5.0;
  static const double LabelPadRight = 1.0;
  static const int TickDistance = 16;
  static const int TextTickDistance = 64;
  static const double TickSize = 15.0;
  static const double SmallTickSize = 5.0;
  double height;
  Canvas canvas;
  double gutterWidth;
  Offset offset;
  double constPosX;
  double stickyTopPosition =0;
  String minMonth;
  int minDay;
  double minMonthPosition=-10000;
  int minMonthYear=0;
  double minDayPosition=-10000;
  Ticks(){
     store.onChange.listen((data){
       print("Changed $data");
      stickyTopPosition = data;
    });
  }
  /// Other than providing the [PaintingContext] to allow the ticks to paint themselves,
  /// other relevant sizing information is passed to this `paint()` method, as well as
  /// a reference to the [Timeline].
  void paint(PaintingContext context, Offset offset, double translation,
      double scale, double height, Timeline timeline) {
    this.height = height;
    this.canvas = context.canvas;
    this.offset = offset;
    double bottom = height;
    double tickDistance = TickDistance.toDouble();
    double textTickDistance = TextTickDistance.toDouble();
    int minYear=-999999999;
      String minYearLabel="";
    /// The width of the left panel can expand and contract if the favorites-view is activated,
    /// by pressing the button on the top-right corner of the timeline.
    gutterWidth = timeline.gutterWidth;
   
    /// Calculate spacing based on current scale
    double perYearScale = tickDistance * scale;
    if (perYearScale > 2 * TickDistance) {
      while (perYearScale > 2 * TickDistance && tickDistance >= 2.0) {
        perYearScale /= 2.0;
        tickDistance /= 2.0;
        textTickDistance /= 2.0;
      }
    } else {
      while (perYearScale < TickDistance) {
        perYearScale *= 2.0;
        tickDistance *= 2.0;
        textTickDistance *= 2.0;
      }
    }

    /// The number of ticks to draw.
    int numTicks = (height / perYearScale).ceil()+2;

    if (perYearScale > TextTickDistance) {
      textTickDistance = tickDistance;
    }

    /// Figure out the position of the top left corner of the screen
    double tickOffset = 0.0;
    double startingTickMarkValue = 0.0;
    double y = ((translation - bottom) / scale);
    
    startingTickMarkValue = y - (y % tickDistance);
   
    tickOffset = -(y % tickDistance) * scale - perYearScale;
    //print("Before tick: $startingTickMarkValue");
    /// Move back by one tick.
    tickOffset -= perYearScale;
    //startingTickMarkValue -= tickDistance;
    //print("After tick: $startingTickMarkValue $numTicks");
    /// Ticks can change color because the timeline background will also change color
    /// depending on the current era. The [TickColors] object, in `timeline_utils.dart`,
    /// wraps this information.
    List<TickColors> tickColors = timeline.tickColors;
    if (tickColors != null && tickColors.length > 0) {
      /// Build up the color stops for the linear gradient.
      double rangeStart = tickColors.first.start;
      double range = tickColors.last.start - tickColors.first.start;
      List<ui.Color> colors = <ui.Color>[];
      List<double> stops = <double>[];
      for (TickColors bg in tickColors) {
        colors.add(bg.background);
        stops.add((bg.start - rangeStart) / range);
      }
      double s =
          timeline.computeScale(timeline.renderStart, timeline.renderEnd);

      /// y-coordinate for the starting and ending element.
      double y1 = (tickColors.first.start - timeline.renderStart) * s;
      double y2 = (tickColors.last.start - timeline.renderStart) * s;

      /// Fill Background.
      ui.Paint paint = ui.Paint()
        ..shader = ui.Gradient.linear(
            ui.Offset(0.0, y1), ui.Offset(0.0, y2), colors, stops)
        ..style = ui.PaintingStyle.fill;

      /// Fill in top/bottom if necessary.
      if (y1 > offset.dy) {
        canvas.drawRect(
            Rect.fromLTWH(
                offset.dx, offset.dy, gutterWidth, y1 - offset.dy + 1.0),
            ui.Paint()..color = tickColors.first.background);
      }
      if (y2 < offset.dy + height) {
        canvas.drawRect(
            Rect.fromLTWH(
                offset.dx, y2 - 1, gutterWidth, (offset.dy + height) - y2),
            ui.Paint()..color = tickColors.last.background);
      }

      /// Draw the gutter.
      canvas.drawRect(
          Rect.fromLTWH(offset.dx, y1, gutterWidth, y2 - y1), paint);
    } else {
      canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, gutterWidth, height),
          Paint()..color = Color.fromRGBO(246, 246, 246, 0.95));
    }

    Set<String> usedValues = Set<String>();
    constPosX = offset.dx + LabelPadLeft - LabelPadRight;
    double constPosY = offset.dy + height;
    
    /// Draw all the ticks.
    for (int i = 0; i <= numTicks; i++) {
      tickOffset += perYearScale;
      int tt = startingTickMarkValue.round();
      tt = -tt;
      //print("i=$i numTicks=$numTicks startingTickMarkValue=$startingTickMarkValue tt=$tt");
      int tickOffsetFlr = tickOffset.floor();
      TickColors colors =
          timeline.findTickColors(offset.dy + height - tickOffsetFlr);
      if (tt % textTickDistance == 0) {
        /// Every `textTickDistance`, draw a wider tick with the a label laid on top.
        canvas.drawRect(
            Rect.fromLTWH(offset.dx + gutterWidth - TickSize,
                offset.dy + height - tickOffsetFlr, TickSize, 1.0),
            Paint()..color = colors.long);

        /// Drawing text to [canvas] is done by using the [ParagraphBuilder] directly.

        int value = tt.round().abs();

        /// Format the label nicely depending on how long ago the tick is placed at.
        String label = getLabel(value, usedValues);
        

        ui.Paragraph tickParagraph = createParagraph(label);
        double posY = constPosY - tickOffsetFlr - tickParagraph.height - 5;
        
        if (posY < height&&posY>0){
          //print("i=$i numTicks=$numTicks startingTickMarkValue=$startingTickMarkValue tt=$tt");
          canvas.drawParagraph(
              tickParagraph,
              Offset(constPosX,
                  posY));
        }
        if (tickDistance == 1 && perYearScale > 200) {
          
          drawMonths(perYearScale, tickOffsetFlr, value);
        }
        if(posY<stickyTopPosition+10&&minYear<tt){
          minYear=tt;
          minYearLabel = label;
        }
        
        ui.Paragraph tickParagraph2 = createParagraph(minYearLabel);
        canvas.drawRect(Rect.fromLTWH(0,stickyTopPosition,gutterWidth, 10), Paint()..color = colors.background);
        canvas.drawParagraph(tickParagraph2,Offset(constPosX,stickyTopPosition));
        
      } else {
        /// If we're within two text-ticks, just draw a smaller line.
        canvas.drawRect(
            Rect.fromLTWH(offset.dx + gutterWidth - SmallTickSize,
                offset.dy + height - tickOffsetFlr, SmallTickSize, 1.0),
            Paint()..color = colors.short);
      }
      startingTickMarkValue += tickDistance;
    }
  }

  String getLabel(int value,usedValues){
    String label;
        if (value < 9000) {
          label = value.toStringAsFixed(0);
        } else {
          NumberFormat formatter = NumberFormat.compact();
          label = formatter.format(value);
          int digits = formatter.significantDigits;
          while (usedValues.contains(label) && digits < 10) {
            formatter.significantDigits = ++digits;
            label = formatter.format(value);
          }
        }
        usedValues.add(label);
        return label;
  }

  drawMonths(double perYearScale, int tickOffsetFlr, int year) {
    double perMonthScale = perYearScale *0.9999/ 12;

    List months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec'
    ];

    months.forEach((month) {
      int index = months.indexOf(month);
      ui.Paragraph tickParagraph = createParagraph(month);
      double y = offset.dy +
          height -
          tickOffsetFlr -
          tickParagraph.height +
          perMonthScale * index;

      if (index > 0 && y>0 && y<height) {
        canvas.drawParagraph(
            tickParagraph, Offset(constPosX, y));
      }
      if((y<stickyTopPosition+20&&y>minMonthPosition)||(minMonth==month && minMonthYear==year)){
          minMonthPosition=y;
          if(minMonthPosition>stickyTopPosition+20)
            minMonthPosition=-1000;
          minMonth = month;
          minMonthYear=year;
      }
      if (perMonthScale > 300&&y+perMonthScale>0&&y<height){
        drawDays(perMonthScale, y,year,index+1,month);
      }
    });
    if(minMonth!=null){
      ui.Paragraph tickParagraph = createParagraph(minMonth);
      canvas.drawRect(Rect.fromLTWH(0,stickyTopPosition+10,gutterWidth, 10), Paint()..color = Colors.white);
      canvas.drawParagraph(tickParagraph, Offset(constPosX, stickyTopPosition+10));
    }
        
  }

  drawDays(double perMonthScale, double _y,int year,int month,String monthName) {
    DateTime lastDate = DateTime(year,month+1,1).subtract(Duration(days: 1));
    double perDayScale = perMonthScale / lastDate.day;

    for (int i = 1; i <= lastDate.day; i++) {
      ui.Paragraph tickParagraph = createParagraph(i.toString());
       double y = _y + perDayScale * (i - 1);
      if (i > 1 && y>0 && y<height) 
        canvas.drawParagraph(tickParagraph, Offset(constPosX, y));
      
      if (perDayScale > 300 &&y+perDayScale>0&&y<height)
        drawHours(perDayScale, y);
      
      if((y<stickyTopPosition+30&&y>minDayPosition)||(minMonth==monthName && minMonthYear==year && minDay == i)){
          minDayPosition=y;
          if(minDayPosition>stickyTopPosition+30)
            minDayPosition=0;
          minDay = i;
      }
    }
    if(minDay!=null){
      ui.Paragraph tickParagraph = createParagraph(minDay.toString());
      canvas.drawRect(Rect.fromLTWH(0,stickyTopPosition+20,gutterWidth, 10), Paint()..color = Colors.white);
      canvas.drawParagraph(tickParagraph, Offset(constPosX, stickyTopPosition+20));
    }
  }

  drawHours(perDayScale, _y) {
    double perHourScale = perDayScale / 24;
    for (int i = 0; i <= 23; i++) {
      ui.Paragraph tickParagraph = createParagraph(i.toString() + ":00");

      double y = _y + perHourScale * i;

      if (i > 0 && y>0 && y< height)
        canvas.drawParagraph(
            tickParagraph, Offset(constPosX, y));
      if (perHourScale > 450 &&y+perHourScale>0&&y<height)
        drawMinutes(perHourScale, y,i);
    }
  }

  formatTime(int _num) {
    return _num > 9 ? _num.toString() : "0" + _num.toString();
  }

  drawMinutes(perHourScale, _y,hourIndex) {
    double perMinuteScale = perHourScale / 60;
    for (int i = 1; i <= 59; i++) {
      ui.Paragraph tickParagraph = createParagraph(hourIndex.toString() + ":" + formatTime(i));
      double y = _y +  perMinuteScale * i;
      if (i > 0 && y>0 && y< height)
        canvas.drawParagraph(
            tickParagraph,
            Offset(constPosX,y));
    }
  }

  ui.Paragraph createParagraph(String text) {
    ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.end, fontFamily: "Roboto", fontSize: 10.0))
      ..pushStyle(ui.TextStyle(color: Color(0x6e000000)));
    builder.addText(text);
    ui.Paragraph tickParagraph = builder.build();
    tickParagraph.layout(ui.ParagraphConstraints(
        width: gutterWidth - LabelPadLeft - LabelPadRight));
    return tickParagraph;
  }
}
