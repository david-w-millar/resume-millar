#!/usr/bin/env groovy
public class WordCloudBuilder {
   static def main(args){
     new File(args[0]).splitEachLine(~/\s/) { fields ->
       if(fields.size() > 0 && !fields[0].contains("#") && fields[0].size() > 0){
         def times = fields[0] as Integer
         def word = fields[1]
         times.toInteger().times { println word }
       }
     }
   }
}
