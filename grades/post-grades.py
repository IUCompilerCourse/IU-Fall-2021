
import csv
import sys

assignment = "Conditionals"
autograder_java_file = assignment + '.csv'
autograder_python_file = assignment + 'Python.csv'
gradebook_file = '2021-10-11.csv'

def column_of(name, row):
    index = 0
    for col in row:
        if col.startswith(name + ' '):
            return index
        index += 1
    print('error, could not find',name,'in',row)
    sys.exit(-1)

assignment_grade = {}

# Load the grades from the autograder CSV files
with open(autograder_java_file) as autograder_csv:
    autograder_reader = csv.reader(autograder_csv, delimiter=",")
    line_count = 0    
    for row in autograder_reader:
        if line_count == 0:
            pass
        else:
            email = row[0]
            grade = row[4]
            userid = email.split('@')[0]
            assignment_grade[userid] = grade
        line_count += 1

with open(autograder_python_file) as autograder_csv:
    autograder_reader = csv.reader(autograder_csv, delimiter=",")
    line_count = 0    
    for row in autograder_reader:
        if line_count == 0:
            pass
        else:
            email = row[0]
            grade = row[4]
            userid = email.split('@')[0]
            if userid in assignment_grade:
                assignment_grade[userid] = str(max(int(grade),int(assignment_grade[userid])))
            else:
                assignment_grade[userid] = grade
        line_count += 1
        
# Output a canvas gradebook file
with open(gradebook_file) as gradebook_csv:
    gradebook_reader = csv.reader(gradebook_csv, delimiter=",")
    line_count = 0
    for row in gradebook_reader:
        if line_count == 0:
            assignment_column = column_of(assignment, row)
            column_number = 0
            for header in row:
                if column_number < 4:
                    print(header,end=',')
                elif column_number == assignment_column:
                    print(header,end='')
                column_number += 1
            print('\n',end='')
        elif line_count == 1 or line_count == 2:
            pass
        else:
            print('"', row[0], '"', sep='',end=',') # Name
            print(row[1],end=',') # ID
            print(row[2],end=',') # User ID
            print('"', row[3], '"', sep='', end=',') # Section
            userid = row[2]
            if userid in assignment_grade:
                print(assignment_grade[userid],end='')
            else:
                print('0',end='')
            print('\n',end='')
        line_count += 1
