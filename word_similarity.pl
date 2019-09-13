# Word_Similarity is a perl script for computing word similarity based on WordNet
# The similarity algorithm is the replication of Yang and Powers "Measuring semantic 
# similarity in the taxonomy of WordNetfive measures" (2005) and "Verb similarity in 
# the taxonomy of WordNet" (2006)
# Copyright (C) 2004-2009, Dongqiang Yang and David M.W. Powers

use strict;
use Switch;
use WordNet::QueryData;

# The current version of WordNet used in the program is 2.0
# Point to the interface to WordNet
print "Loading WordNet...\n";
my $wn = WordNet::QueryData->new;

# Define the path type weight in the taxonomy of wordnet. The relations "same"-identical, "syn"-synonym", 
# and "ant"-antonyms are applied on all PoS tags. For nouns, "hhhm" includes hyper/hypohym and holo/meronym. 
# For verbs, besides "hhhm"-Tropo/hyponym, "enta"-entailment and "caus"-caused and "deri"-derived noun forms 
# are also used. For adjectives, the relations entails "also"-"A noun for which adjectives express values",
# "pert"-"A relational adjective", "sim"-"similar to", and "attr"-"attributes". For adverbs, "pert" is the only
# relation that can be traced. 
# These values are adjustable to satisfy specific needs with values from 0 to 1.

my %Relation_wt=("same",1,"syn",0.9,"ant",0.9,"hhhm",0.85,"enta",0.85,"caus",0.85,"also",0.85,"sim",0.85,"pert",0.85,"deri",0.8,"iden",0.7,"gloss",0.5);
 
# We define different link type values in the nominal and verbal hierarchies.
# These link weights can be optimised between 0 and 1.

my %Path_wt=("n",0.7,"v",0.2);

# Search word relationships the path length starting from each target is no more than 2 links so that the
# distance between two words is less than 4 links.

# This value can be adjusted to reduce running time or in contrast to find deeper word relationships
# It's usually set up between 1 and 4

my $Path_len=2;

# Mark if a word defined in WordNet

my $tag; 

# The PoS tag of a word

my $pos;

# The words input and their corresponding synsets

my ($input1, $input2);
my ($Synset_wd1, $Synset_wd2);

# The maximum similarity scores between words through their respective synset comparision. 

my $max_score;

# Record every concepts visited during searching so that avoiding querying wordnet database

my %visit_node;

my $line;
my $var;
my @input_word;
my $total_pairs;
my $count;

#读取文件
open(input,"C:/Strawberry/project/word_similarity/perl_word_similarity/data_set/SimVerb-3000-test.csv".$ARGV[0]) || die("open input.txt failed\n");
 while (!(eof(input))) {
   $line=<input>; 
   if ($line !~ /^\s/) {
    #print "<<$line\n";
	@input_word=split(",",$line);chomp(@input_word);
	#print "$input_word[0]\n";	
	my $count=1;
while($count <=@input_word){
   #print "\nThe current two words are: \n";
   print "word$count: $input_word[$count-1]\n";
   $count++;
}
}  
  $input1=$input_word[$count-1];chomp($input1);
  $input2=$input_word[$count];chomp($input2);
  if ($input1 =~ /^\s+|^$/ or $input2 =~ /^\s+|^$/) {print "\nEmpty input error!\n";next;};
  if ($input1 eq $input2) {print "\nNo sense comparison on same\n"; next;}
  else { print "\nTo calculate the similarity/relatednss between ", $input1, " and ", $input2, "\n";}
  ($tag, $Synset_wd1, $Synset_wd2)=&in_wn($input1, $input2);
  next if $tag == 0;
  if (scalar (@$Synset_wd1) >0 and scalar (@$Synset_wd2) >0) {
    # The maximum similarity scores between words through their respective synset comparision. 
    $max_score=0;
    foreach my $tmp1 (@$Synset_wd1) {
      switch ($tmp1) {
	case (/#n.*$/) {
	  print "\nStep 1: Treat the first input ",$input1," as a noun: ",$tmp1,"...\n";
	  foreach my $tmp2 (@$Synset_wd2) {
	    switch ($tmp2) {
	      case (/#n.*$/) {
	        &find_relation($tmp1,$tmp2,"n");
	      }
	      case (/#v.*$/) {
                my @der_synset2=$wn->queryWord($tmp2, "deri");
		foreach my $tmp_der2 (@der_synset2) {&find_relation($tmp1,$tmp_der2,"n");}
	      }
	      case (/#a.*$/) {
	        my @per_synset2=$wn->queryWord($tmp2, "pert");
		foreach my $tmp_per2 (@per_synset2) {&find_relation($tmp1,$tmp_per2,"n");}
		my @att_synset2=$wn->querySense($tmp2, "attr");
		foreach my $tmp_att2 (@att_synset2) {&find_relation($tmp1,$tmp_att2,"n");}
              }
	      case (/#r.*$/) {next}
	    }
	  }
	}
	case (/#v.*/) {
	  print "\nStep 2:Treat the first input ",$input1," as a verb:",$tmp1,"...\n";
          my @der_synset1=$wn->queryWord($tmp1, "deri");
	  foreach my $tmp2 (@$Synset_wd2) {
	    switch ($tmp2) {
	      case (/#v.*$/) {
	        print "compare both verbs: $tmp1,$tmp2\n";
	        &find_relation($tmp1,$tmp2,"v")
              }
	      case (/#n.*$/) {
	        foreach my $tmp_der1 (@der_synset1) {&find_relation($tmp_der1,$tmp2,"n");}
	      }
	      case (/#[a,r].*$/) {next}
	    }
	  }
	}
	case (/#a.*/) {
          print "\nStep 3: Treat the first input ",$input1," as an adjective:",$tmp1,"...\n";
	  my @att_synset1=$wn->querySense($tmp1, "attr");
          my @der_synset1=$wn->queryWord($tmp1, "pert");
	  foreach my $tmp2 (@$Synset_wd2) {
	    switch ($tmp2) {
	      case (/#v.*$/) {next}
	      case (/#n.*$/) {
		foreach my $tmp_att1 (@att_synset1) {&find_relation($tmp_att1,$tmp2,"n");}		 
	        foreach my $tmp_der1 (@der_synset1) {&find_relation($tmp_der1,$tmp2,"n");}
	      }
	      case (/#a.*$/) {&find_relation($tmp1,$tmp2,"a")}
	      case (/#r.*$/) {next}
	    }
	  }
        }
	case (/#r.*/) {	
	  print "\nStep 4: Treat the first input ",$input1," as an adverb:",$tmp1,"...\n";
	  my @per_synset1=$wn->queryWord($tmp1, "pert");
	  foreach my $tmp2 (@$Synset_wd2) {
	    switch ($tmp2) {
	      case (/#[v,n].*$/) {next}
	      case (/#a.*$/) {
	        foreach my $tmp_per1 (@per_synset1) {&find_relation($tmp_per1,$tmp2,"a");}
	      }
	      case (/#r.*$/) {&find_relation($tmp1,$tmp2,"r")}
	    }
	  }
        }      
     }
   }
 }
 #undef(%visit_node);
 print "\nThe maximum score is $max_score\n";
open (OUTFILE,">>C:/Strawberry/project/word_similarity/perl_word_similarity/test/3000.csv\n");
print OUTFILE "$max_score\n";
close(OUTFILE); 
 
 
}

# Check up if the input word can be found in wordnet and return its synsets across all PoS tags

sub in_wn
{ 
 my ($wd1,$wd2)=@_; 
 my @Pos_wd1=$wn->validForms($wd1);
 my @Pos_wd2=$wn->validForms($wd2);
 my @Synset_wd1;
 my @Synset_wd2;
 if (scalar(@Pos_wd1) > 0 and scalar(@Pos_wd2) > 0) {
   foreach my $tmp (@Pos_wd1) {push (@Synset_wd1, $wn->querySense($tmp));}
   foreach my $tmp (@Pos_wd2) {push (@Synset_wd2, $wn->querySense($tmp));}
   return (1, \@Synset_wd1, \@Synset_wd2);
 }   
 else {
   if (scalar(@Pos_wd1) == 0) {print "No valid forms for the terms $wd1 in WordNet\n";}
   if (scalar(@Pos_wd2) == 0) {print "No valid forms for the terms $wd2 in WordNet\n";}
   return (0);
 }
}

# Search word relationships in wordent and to score them as a return. Here the final score is maximum among
# concept comparision. The mean or sum values can be considerated 

sub find_relation
{
 my ($Synset1,$Synset2,$pos)=@_;
 my $buf;
 my @score;
  
 if (&find_syn($Synset1,$Synset2)) { # If $synset1 is a synonym of $synset2
   print "in find_syn $Synset1, $Synset2\n";
   $max_score=$Relation_wt{"syn"};}
 elsif (&find_anti($Synset1,$Synset2)) { # If $synset1 is an antonym of $synset2
   print "in find_ant $Synset1, $Synset2\n";
   $max_score=$Relation_wt{"ant"};}
 else {
   switch ($pos) {
     case ("n") {
       push (@score, &find_deep_coordi($Synset1,$Synset2,"hype",$Path_len*2-1,$pos));
       push (@score, &find_deep_coordi($Synset1,$Synset2,"hypo",$Path_len*2-1,$pos));
       push (@score, &find_deep_coordi($Synset1,$Synset2,"holo",$Path_len*2-1,$pos));   
       push (@score, &find_deep_coordi($Synset1,$Synset2,"mero",$Path_len*2-1,$pos)); 
     }
     case ("v") {
       if (&find_form($Synset1,$Synset2)) {
         print "in find_form $Synset1,$Synset2 \n"; 
         push(@score,$Relation_wt{"iden"});
       } 
       else {
         push (@score, &find_deep_coordi($Synset1,$Synset2,"hype",$Path_len*2-1,$pos));
         push (@score, &find_deep_coordi($Synset1,$Synset2,"hypo",$Path_len*2-1,$pos));
	 push (@score, &find_deep_coordi($Synset1,$Synset2,"enta",$Path_len*2-1,$pos));   
         push (@score, &find_deep_coordi($Synset1,$Synset2,"caus",$Path_len*2-1,$pos));
         $buf=&find_sis($Synset1,$Synset2,"deri");
	 push (@score,$buf) if $buf != 0;
       }
     }
     case ("a") {
       if (&find_adj($Synset1,$Synset2,"also")) {
         print "in find_adj $Synset1, $Synset2, also \n";
	 push(@score,$Relation_wt{"also"});
       }
       elsif (&find_adj($Synset1,$Synset2,"sim")) {
         print "in find_adj $Synset1, $Synset2, sim \n";
	 push(@score,$Relation_wt{"sim"});
       }
       else {
         $buf=&find_sis($Synset1,$Synset2,"attr");
	 push (@score,$buf) if $buf != 0;
	 $buf=&find_sis($Synset1,$Synset2,"pert");
	 push (@score,$buf) if $buf != 0;
       }
     }
     case ("r") {
       $buf=&find_sis($Synset1,$Synset2,"pert");
       push (@score,$buf) if $buf != 0;
     }  
   }
   foreach my $tmp (@score) {
     $max_score = $tmp if $tmp > $max_score;
   }
 }
 return ($max_score);
}

# Match between $synset1 and $synset2 to see if they are syns

sub find_syn 
{
 my ($synset1,$synset2)=@_;
 my @syns=$wn->querySense($synset1,"syns");
 foreach my $tmp (@syns) { return (1) if $tmp =~ /^$synset2$/;}
}

# Match between $synset1 and $synset2 to see if they are ants

sub find_anti
{ 
 my ($synset1, $synset2)=@_;
 my @ants=$wn->queryWord($synset1,"ants");
 foreach my $tmp (@ants) { return (1) if &find_syn($tmp, $synset2);}
}

# Match between $synset1 and $synset2 to see if they are of same word form

sub find_form
{
 my ($synset1,$synset2)=@_;
 my @syn1=$wn->querySense($synset1,"syns");
 my @syn2=$wn->querySense($synset2,"syns");
 foreach my $tmp1 (@syn1)  {
   $tmp1 =~ s/#.*//g;
   foreach my $tmp2 (@syn2)  {return (1) if $tmp2 =~ /^$tmp1#/;}
 }
}

# Search the semantic relations between the derived forms of $synset1 and $synset2.

sub find_sis
{
 my ($synset1,$synset2,$rel)=@_;
 my @deri1=$wn->queryWord($synset1,$rel);
 my @deri2=$wn->queryWord($synset2,$rel);
 my $score;
 my $pos;
 foreach my $tmp1 (@deri1)  {
   foreach my $tmp2 (@deri2) {
     $tmp2 =~ /(.*#)([n,v,a,r])(#.*)/; $pos=$2;
     $score=&find_relation($tmp1,$tmp2,$pos);
     print "in find_sis, $synset1, $synset2, $rel, $score\n"; 
     return ($score*$Relation_wt{"rel"}) if $score != 0;
   }
 }
}

# Search only for adjectives

sub find_adj 
{
 my ($synset1,$synset2,$rel)=@_;
 my @syns=$wn->querySense($synset1,$rel);
 foreach my $tmp (@syns) { 
   return (1) if &find_syn ($tmp, $synset2) or &find_anti($tmp, $synset2);
 }
}

# For both nouns and verbs, search if $word1_synset.$type is $word2_synset within the search scope of
# $depth. $in_depth defines the depth that $word1_synset has gone through

sub find_link
{ 
 my ($word1_synset,$word2_synset,$type,$depth,$in_depth,$pos)=@_;
 my $visit_depth=2*$Path_len-$in_depth-$depth+1;
 my @temp_link;
 my $buf;
 my $temp;
 if (!defined($visit_node{join("#",$type,$visit_depth,$word1_synset)})) { 
   @temp_link=$wn->querySense($word1_synset,$type);
   $visit_node{join("#",$type,$visit_depth,$word1_synset)}=join("%",@temp_link);
 }
 else {
   @temp_link=split(/%/,$visit_node{join("#",$type,$visit_depth,$word1_synset)});
 } 
 foreach $temp (@temp_link) {
   if (&find_syn($temp,$word2_synset)) {     
     $buf=$Relation_wt{"hhhm"}*($Path_wt{$pos}**($in_depth+$visit_depth-1));
     print "in find_link_syn, $word1_synset, $word2_synset, $type, $buf \n"; 
     return ($buf);
   }
   elsif (&find_anti($temp,$word2_synset)) {
     $buf=$Relation_wt{"hhhm"}*($Path_wt{$pos}**($in_depth+$visit_depth-1));
     print "in find_link_ant,$word1_synset, $word2_synset, $type, $buf \n";
     return ($buf);
   }
   elsif (($pos eq "v") and &find_form($temp,$word2_synset)) {
     $buf=$Relation_wt{"iden"}*$Relation_wt{"hhhm"}*($Path_wt{$pos}**($in_depth+$visit_depth-1));
     print "in find_link_form,$word1_synset, $word2_synset, $type, $buf \n";
     return ($buf);
   }    
   if ($depth > 1) {
     $depth--;
     $buf = &find_link($temp,$word2_synset,$type,$depth,$in_depth,$pos);
     $depth++;
     return ($buf)  if $buf > 0;
   }
 }
}

# Search if $synset1.$type is equal to $synset2 within the depth of $synset1

sub find_deep_coordi
{ 
 my ($synset1,$synset2,$type,$depth,$pos)=@_;
 my @temp_link=$wn->querySense($synset1,$type);
 my $visit_depth=2*$Path_len-$depth;

 # The depth that $synset1 has gone through

 my $buf;
 my $temp;
 my @score;

 # Record every similarity scores between $synset1 and $synset2

 foreach $temp (@temp_link)  {
   if (&find_syn($temp,$synset2)) {
     print "in find_deep_syn, $synset1, $synset2, $type \n";
     push (@score, $Relation_wt{"hhhm"}*($Path_wt{$pos}**($visit_depth-1)));
     ($visit_depth <= $Path_len) ? (return (@score)):(next);
   }
   elsif (&find_anti($temp,$synset2)) {
     print "in find_deep_ant, $synset1, $synset2, $type \n";
     push (@score, $Relation_wt{"hhhm"}*($Path_wt{$pos}**($visit_depth-1)));
     ($visit_depth <= $Path_len) ? (return (@score)):(next);
   }
   elsif (($pos eq "v") and &find_form($temp,$synset2)) {
     print "in find_deep_form, $synset1, $synset2, $type \n";
     push (@score, $Relation_wt{"iden"}*$Relation_wt{"hhhm"}*($Path_wt{$pos}**($visit_depth-1)));
   }    
   if ($depth > 1) {
     $depth--;
     push(@score, &find_deep_coordi($temp,$synset2,$type,$depth,$pos))
     ;     
   }
   $depth=2*$Path_len-$visit_depth;

   # The searching depth of the sencond concept $synset2

   switch ($depth) {
     case ([1,3]) {
       switch ($type) {
         switch ($pos) {
	   case ("n") {
	     $buf=&find_link($synset2,$temp,$type,$depth,$visit_depth,$pos);
	     push(@score,$buf) if $buf != 0;
	   }
	   case ("v") {
	     $buf=&find_link($synset2,$temp,$type,$depth,$visit_depth,$pos);
	     push(@score,$buf) if $buf != 0;
	     $buf=&find_link($synset2,$temp,"enta",$depth,$visit_depth,$pos);
	     push(@score,$buf) if $buf != 0;
	     $buf=&find_link($synset2,$temp,"caus",$depth,$visit_depth,$pos);
	     push(@score,$buf) if $buf != 0;
	   }
	 }	 
	 case (/hype|hypo/) {
	   switch ($pos) {
	     case ("n") {
	       $buf=&find_link($synset2,$temp,"holo",$depth,$visit_depth,$pos);
	       push(@score,$buf) if $buf != 0;
	       $buf=&find_link($synset2,$temp,"mero",$depth,$visit_depth,$pos);
	       push(@score,$buf) if $buf != 0;
	     }
	     case ("v") {
	       $buf=&find_link($synset2,$temp,"caus",$depth,$visit_depth,$pos);
	       push(@score,$buf) if $buf != 0;
	       $buf=&find_link($synset2,$temp,"enta",$depth,$visit_depth,$pos);
	       push(@score,$buf) if $buf != 0;
	     }
	   }
	 }	 
	 case (/holo|mero|enta|caus/) {
	   $buf=&find_link($synset2,$temp,"hype",$depth,$visit_depth,$pos);
	   push(@score,$buf) if $buf != 0;
	   $buf=&find_link($synset2,$temp,"hypo",$depth,$visit_depth,$pos);
	   push(@score,$buf) if $buf != 0;
	 }
       }
     }
     case (2) {
       $buf=&find_link($synset2,$temp,"hype",$depth,$visit_depth,$pos);
       push(@score,$buf) if $buf != 0;
       $buf=&find_link($synset2,$temp,"hypo",$depth,$visit_depth,$pos);
       push(@score,$buf) if $buf != 0;
       switch ($pos) {
         case ("n") {
	   $buf=&find_link($synset2,$temp,"holo",$depth,$visit_depth,$pos);
	   push(@score,$buf) if $buf != 0;
           $buf=&find_link($synset2,$temp,"mero",$depth,$visit_depth,$pos);
	   push(@score,$buf) if $buf != 0;
	 }
	 case ("v") {
	   $buf=&find_link($synset2,$temp,"enta",$depth,$visit_depth,$pos);
	   push(@score,$buf) if $buf != 0;
           $buf=&find_link($synset2,$temp,"caus",$depth,$visit_depth,$pos);
	   push(@score,$buf) if $buf != 0;
	 }
       }
     }     
   }
 }
 return (@score);
}
     
