# create_annotations.py

import argparse
import csv
import glob
import sqlite3
import dbm
def parse_domtblouts(datadir):
  sequences= {}
  for dfile in glob.glob(datadir+"/*.domtblout"): #iterate through domtblouts, grouping 
                                               #hits by sequence
    with open(dfile, "r") as din:
      for line in din:  
        if line[0] != '#':  #line with valid data
          fields = line.split()
          sequence = fields[0]
          domain = fields[3]
          eval = float(fields[12])  # i-Evalue
          alifrom = int(fields[17])
          alito = int(fields[18])
          envfrom = int(fields[19])
          envto = int(fields[20])
          dtuple=[domain, eval, alifrom, alito, envfrom, envto]
          if eval <= 0.01:
            if sequence not in sequences:
              sequences[sequence] = [dtuple]
            else:
              sequences[sequence] += [dtuple]
  
  #now, sort each sequence's domains by alifrom
  for sequence in sequences.keys():
    sequences[sequence]= sorted(sequences[sequence], key = lambda x: x[2])
  return sequences

def resolve_overlaps(sequencedict, clanfile):
  clans = {}
  with open(clanfile, 'r') as cf:
    for line in csv.reader(cf, delimiter='\t'):
      family = line[3]
      clan = line[2]
      clans[family] = clan

  for skey in sequencedict.keys():
    newsequence = []
    domains = sequencedict[skey]
    current_domain = domains[0]
    next = 1
    while next < len(domains):
      next_domain = domains[next]
      if len(next_domain) != 6:
        print("Broken domain with length "+ str(len(next_domain)) + " found in sequence "+skey + " domain "+ domain[0])
      if current_domain[3] > next_domain[2]: #overlap, end[current] > start[next]
        if clans[current_domain[0]] != "" and clans[current_domain[0]] == clans[next_domain[0]]:
          #same clan, so drop the doain with worse evalue
          #print("Clan overlap found in "+skey+" "+current_domain[0]+ " and "+ next_domain[0] + " from " + str(current_domain[3]) + " to " + str(next_domain[2]))
          if current_domain[3] - next_domain[2] < 5:  #Small overlap, shorten domain with higher evalue
            if current_domain[1] <= next_domain[1]: #Current has better evalue
              #print("shrinking second domain")
              next_domain[2] = current_domain[3] + 1 #shorten next domain to eliminate overlap
              if next_domain[2] < next_domain[3]:   #domain hasn't shrunk out of existence
                newsequence += [current_domain]
                current_domain = next_domain
                next +=1
              else:  # next domain went away, skip it
                next+=1
            else:  #next domain has better evalue
              #print("shrinking first domain")
              current_domain[3] = next_domain[2] -1  #shrink current domain to eliminate overlap
              if current_domain[2] < current_domain[3]: #current domain  still exists, push it onto newsequence
                newsequence += [current_domain]

              current_domain = next_domain
              next += 1
          else: #Big overlap, drop domain with higher evalue
            if current_domain[1] <= next_domain[1]:
              #drop next_domain
              #print("Dropping second domain")
              next +=1
            else:
              current_domain = next_domain
              #print("dropping first domain")
              next+=1
        else: #no domain or different domains, so shorten the one with worse e-value
          #print("Non-clan overlap found in "+skey+" "+current_domain[0]+ " and "+ next_domain[0]+ " from " + str(current_domain[3]) + " to " + str(next_domain[2]))

          if current_domain[1] <= next_domain[1]: #Current has better evalue
            #print("shrinking second domain")
            next_domain[2] = current_domain[3] + 1 #shorten next domain to eliminate overlap
            if next_domain[2] < next_domain[3]:   #domain hasn't shrunk out of existence
              newsequence += [current_domain]
              current_domain = next_domain
              next +=1
            else:  # next domain went away, skip it
              next+=1
          else:  #next domain has better evalue
            #print("shrinking first domain")
            current_domain[3] = next_domain[2] -1  #shrink current domain to eliminate overlap
            if current_domain[2] < current_domain[3]: #current domain  still exists, push it onto newsequence
              newsequence += [current_domain]

            current_domain = next_domain
            next += 1

      else:
        newsequence += [current_domain]
        current_domain = next_domain
        next +=1

    if current_domain != "":
      newsequence += [current_domain]
  
    sequences[skey] = newsequence
    
  return sequencedict

parser = argparse.ArgumentParser()
parser.add_argument("domtbldir", help="Directory containing .domtblout files of search results")
parser.add_argument("clanfile", help="TSV-fomatted file of domain->clan mappings")
parser.add_argument("outfileName", help="Name of the output file")
args = parser.parse_args()

sequences = parse_domtblouts(args.domtbldir)

sequences = resolve_overlaps(sequences, args.clanfile)

#Now, write the annotations to a database
#conn=sqlite3.connect(args.outfileName)
#c= conn.cursor()
#c.execute('''CREATE TABLE annotations (sequence text, domain text)''')
print("starting write to database")

with dbm.open(args.outfileName, 'n') as db:
  for key in sequences.keys():
    annotation = ""
    for domain in sequences[key]:
      if annotation !="":
        annotation+= ","
      annotation += domain[0]
      annotation +=","
      annotation += str(domain[1])
      annotation += ","
      annotation += str(domain[2])
      annotation += ","
      annotation += str(domain[3])
      annotation += ","
      annotation += str(domain[4])
      annotation += ","
      annotation += str(domain[5])
    db[key] = annotation
  #row = (key, annotation)
  #c.execute("INSERT INTO annotations VALUES (?, ?)", row)
  
#conn.commit()
#conn.close()
