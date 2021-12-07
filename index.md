## Course Webpage for Compilers (P423, P523, E313, and E513)

Indiana University, Fall 2021


High-level programming languages like Racket and Python make it easier
to program compared to low-level languages such as x86 assembly
code. But how do high-level languages work? There's a big gap between
high-level languages and machine instructions for modern computers. In
this class you learn how to translate Racket or Python programs (your
choice!) all the way to x86 assembly language.

Traditionally, compiler courses teach one phase of the compiler at a
time, such as parsing, semantic analysis, and register allocation. The
problem with that approach is it is difficult to understand how the
whole compiler fits together and why each phase is designed the way it
is. Instead, each week we implement a successively larger subset of
the input language. The very first subset is a tiny language of
integer arithmetic, and by the time we are done the language includes
first-class functions.

**Prerequisites:** Fluency in Racket or Python is highly recommended
as students will do a lot of programming in one of those
languages. Prior knowledge of an assembly language helps, but is not
required.

**Textbook:** 

* The Racket version of the textbook for the course available
  [here](https://www.dropbox.com/s/ktdw8j0adcc44r0/book.pdf?dl=1).
* The Python version of the textbook for the course available
  [here](https://www.dropbox.com/s/mfxtojk4yif3toj/python-book.pdf?dl=1).

If you have suggestions for improvement, please either send an email
to Jeremy or, even better, make edits to a branch of the book and
perform a pull request. The book is at the following location on
github:

    https://github.com/IUCompilerCourse/Essentials-of-Compilation

**Lecture:** Tuesdays and Thursdays 3:15-4:30pm, Informatics Building
  (Myles Brand Hall), Room E130.

**Office hours**

* Jeremy Siek (jsiek): Mon 11am-noon, Tue 2-3pm, in Luddy 3014 (or nearby).

**Topics:**

* Instruction Selection

* Register Allocation

* Static type checking

* Conditional control flow

* Mutable data

* Garbage collection

* Procedures and calling conventions

* First-class functions and closure conversion

* Dynamic typing

* Generics

* High-level optimization (inlining, constant folding, copy
  propagation, etc.)

**Grading:**

Course grades are based on the following items. For the weighting, see
the Canvas panel on the right-hand side of this web page.  Grading
will take into account any technology problems that arrise, i.e., you
won't fail the class because your internet went out.

* Assignments (40%)
* Midterm Exam (October 21, in class) (25%)
* Final Exam (December 14, 12:35-2:35 PM, in class) (35%)

**Assignments:**

Organize into teams of 2-4 students. Assignments will be due bi-weekly
on Mondays at 11:59pm. Teams that include one or more graduate
students are required to complete the challenge exercises.

Assignment descriptions are posted on Canvas.  Turn in your
assignments by submitting your code to the
[autograder](https://autograder.sice.indiana.edu/web/course/28).
There is a Racket and Python version of each assignment.  Submit your
`compiler` file, either `compiler.rkt` or `compiler.py` depending on
the language you are using.

Assignments will be graded based on how many test cases they succeed
on. Partial credit will be given for each "pass" of the compiler.
Some of the tests are in the public support code (see Resources
below). The testing will be done on a linux (ubuntu) machine. The
testing will include both new tests and all of the tests from prior
assignments.

You may request feedback on your assignments prior to the due date.
Just submit your work to the autograder and send us email.

Students are responsible for understanding the entire assignment and
all of the code that their team produces. The midterm and final exam
are designed to test a student's understanding of the assignments.

Students are free to discuss and get help on the assignments from
anyone or anywhere. When posting questions on Slack, it is OK to post
your code.

In contrast, for quizzes and exams, students are asked to work
alone. The quizzes and exams are closed book.

The Final Project is due Dec. 10 and may be turned in late up to
Dec. 15.

**Late assignment policy:** Assignments may be turned in up to one
week late with a penalty of 10%.

**Slack Chat/Messaging:**
  [Workspace](https://iucompilercou-vm16750.slack.com) (
  [signup](https://join.slack.com/t/slack-55j8169/shared_invite/zt-ulktwirl-CoKBrKGdKanD_R50e9Q46g)
  using your iu email address).

**Schedule**

Day     | Lecture Topic                        | Reading Due                   | Assignment Due
Aug. 24 | [Introduction](./lectures/Aug-24.md) |                               |
Aug. 26 | [Compiling from LVar to x86](./lectures/Aug-26.md) | Ch. 1          |
Aug. 31 | [Uniquify, Remove Complex Operands, Explicate Control](./lectures/Aug-31.md) | Ch. 2         |
Sep. 2  | [Select Instructions, Assign Homes, Patch Instructions, Prelude & Conclusion](./lectures/Sep-2.md) | | 
Sep. 6  |                                      |                               | [Integers and Variables](https://iu.instructure.com/courses/1996310/assignments/12582634), submit in [Racket](https://autograder.sice.indiana.edu/web/project/319) or [Python](https://autograder.sice.indiana.edu/web/project/320)
Sep. 7 | [Register Allocation: liveness analysis, interference graph](./lectures/Sep-7.md)  |         | 
Sep. 9 | Code Review: Integers and Variables   | Ch. 3    |
Sep. 14 | [Register Allocation: graph coloring](./lectures/Sep-14.md)  |                               |
Sep. 16 | [The LIf language & type checking](./lectures/Sep-16.md)           |                               |
Sep. 20 |                                      |                               |  [Register Allocation](https://iu.instructure.com/courses/1996310/assignments/12689957), submit in [Racket](https://autograder.sice.indiana.edu/web/project/326) or [Python](https://autograder.sice.indiana.edu/web/project/327)
Sep. 21 | Code Review: Register Allocation     |       Ch. 4                  |
Sep. 23 | [Compiling LIf to x86](./lectures/Sep-23.md)
Sep. 28 | [Compiling LIf to x86, cont'd](./lectures/Sep-28.md)        |
Sep. 30 | [Loops and Dataflow Analysis](./lectures/Sep-30.md)
Oct. 4  |                                      |                               |  [Booleans and Conditionals](https://iu.instructure.com/courses/1996310/assignments/12714002), submit in [Racket](https://autograder.sice.indiana.edu/web/project/330) and [Python](https://autograder.sice.indiana.edu/web/project/331)
Oct. 5 | [More Dataflow Analysis](./lectures/Oct-5.md) | |
Oct. 7 | Code Review: Conditionals
Oct. 12 | [Loops: RCO, Explicate, Remove Jumps](./lectures/Oct-12.md)
Oct. 14 | [Tuples and Garbage Collection](./lectures/Oct-14.md)
Oct. 18 |                                      |                               |  [Loops and Dataflow Analysis](), submit in [Racket](https://autograder.sice.indiana.edu/web/project/335) or [Python](https://autograder.sice.indiana.edu/web/project/336)
Oct. 19 | Review for Midterm
Oct. 21 | **Midterm Exam**
Oct. 26 | [Tuples and GC, cont'd](./lectures/Oct-26.md)
Oct. 28 | [Tuples and GC, cont'd](./lectures/Oct-28.md)
Nov. 2  | [Compiling Functions to x86](./lectures/Nov-2.md)
Nov. 4  | [Compiling Functions, cont'd](./lectures/Nov-4.md)
Nov. 8  |                                      |                               |  [Tuples and Garbage Collection](https://iu.instructure.com/courses/1996310/assignments/12803441), submit in [Racket](https://autograder.sice.indiana.edu/web/project/343) or [Python](https://autograder.sice.indiana.edu/web/project/344)
Nov. 9  | [Example: Simple Call](./lectures/Nov-9.md)
Nov. 11 | [Examples: Tail Calls, Many Parameters](./lectures/Nov-11.md)
Nov. 16 | [Compiling Lambda](./lectures/Nov-16.md)
Nov. 18 | [Examples of Closure Conversion](./lectures/Nov-18.md)
Nov. 29 |                                      |                               |  [Functions](https://iu.instructure.com/courses/1996310/assignments/12844466), submit in [Racket](https://autograder.sice.indiana.edu/web/project/349) or [Python](https://autograder.sice.indiana.edu/web/project/350)
Nov. 30 | Code Review: Functions
Dec. 2 | [Dynamic Typing](./lectures/Dec-2.md)
Dec. 7 | [Dynamic Typing, continued](./lectures/Dec-7.md)
Dec. 14 | **Final Exam** 12:35-2:35 p.m. in class


**Resources:**

* Lecture videos recorded from last year's [class](https://iucompilercourse.github.io/IU-P423-P523-E313-E513-Fall-2020/).
* Github repository for the support code and test suites
    - for [Racket](https://github.com/IUCompilerCourse/public-student-support-code) 
	- for [Python](https://github.com/IUCompilerCourse/python-student-support-code)
* Web server for running the reference compiler on a program: [Racket version](https://homes.luddy.indiana.edu/classes/fall2021/engr/e513-jsiek/compiler.php)
* [Racket Download](https://download.racket-lang.org/)
* [Racket Documentation](https://docs.racket-lang.org/)
* [Python 3.10 Download](https://www.python.org/downloads/release/python-3100rc1/)
* [Python 3.10 Documentation](https://docs.python.org/3.10/)
* [Python ast module declarations](https://github.com/python/typeshed/blob/master/stdlib/_ast.pyi)
* [Notes on x86-64 programming](http://web.cecs.pdx.edu/~apt/cs491/x86-64.pdf)
* [x86-64 Machine-Level Programming](https://www.cs.cmu.edu/~fp/courses/15411-f13/misc/asm64-handout.pdf)
* [Intel x86 Manual](http://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-manual-325462.pdf?_ga=1.200286509.2020252148.1452195021)
* [System V Application Binary Interface](https://software.intel.com/sites/default/files/article/402129/mpx-linux64-abi.pdf)
* [Uniprocessor Garbage Collection Techniques](https://iu.instructure.com/courses/1735985/files/82131907/download?wrap=1) by Wilson. 
* [Fast and Effective Procedure Inlining](https://www.cs.indiana.edu/~dyb/pubs/inlining.pdf) by Waddell and Dybvig.


**COVID Policies and Precautions**

All students signed the Community Responsibility Acknowledgement
(CRA).  Your agreement to the public health measures in the CRA is a
condition of physical presence on the campus this fall.  Included in
that commitment were the requirements to be vaccinated, for wearing
masks in all IU buildings, and maintaining social distancing in all IU
buildings. These are classroom requirements.

These requirements are necessary for us to protect each other.

Therefore, if a student is present in a class without a mask, the
student will be asked to put on a mask and I will report the student
to the Division of Student Affairs: Office of Student Conduct.

* If a student refuses to put a mask on after being instructed to do
  so, the instructor may end the class immediately, and contact the
  Office of Student Conduct.  Violation of the mask rule is a threat
  to public safety within the meaning of the Summary Suspension Policy.
* If a student comes to class without a mask twice, the student’s
  final grade will be reduced by one letter (e.g., from an A to a B,
  for instance).
* If the student comes to class without a mask three times, the
  student will be withdrawn from the class without refund of tuition
  and reported to the Office of Student Conduct.
* If Student Conduct receives three cumulative reports from any
  combination of instructors or staff members that a student is not
  complying with the requirements of masking and physical distancing,
  the student will be summarily suspended from the university for the
  semester.
	
	
**Bias-Based Incident Reporting.**

Bias-based incident reports can be made by students, faculty and
staff. Any act of discrimination or harassment based on race,
ethnicity, religious affiliation, gender, gender identity, sexual
orientation or disability can be reported through any of the options:

1) email biasincident@indiana.edu or incident@indiana.edu;

2) call the Dean of Students Office at (812) 855-8188 or

3) use the IU mobile App (m.iu.edu). Reports can be made anonymously.

**Dean on Call.**

The Dean of Students office provides support for students dealing with
serious or emergency situations after 5 p.m. in which an immediate
response is needed and which cannot wait until the next business
day. Faculty or staff who are concerned about a student’s welfare
should feel free to call the Dean on Call at (812) 856-7774. This
number is not to be given to students or families but is for internal
campus use only. If someone is in immediate danger or experiencing an
emergency, call 911.

**Boost.**

Indiana University has developed an award-winning smartphone app to
help students stay on top of their schoolwork in Canvas. The app is
called “Boost,” it is available for free to all IU students, and it
integrates with Canvas to provide reminders about deadlines and other
helpful notifications. For more information, see
https://kb.iu.edu/d/atud.

**Counseling and Psychological Services.**

CAPS has expanded their services. For information about the variety of
services offered to students by CAPS visit:
http://healthcenter.indiana.edu/counseling/index.shtml.


**Disability Services for Students (DSS).**

The process to establish accommodations for a student with a
disability is a responsibility shared by the student and the DSS
Office. Only DSS approved accommodations should be utilized in the
classroom. After the student has met with DSS, it is the student’s
responsibility to share their accommodations with the faculty
member. For information about support services or accommodations
available to students with disabilities and for the procedures to be
followed by students and instructors, please visit:
https://studentaffairs.indiana.edu/disability-services-students/.

**Reporting Conduct and Student Wellness Concerns.**

All members of the IU community including faculty and staff may report
student conduct and wellness concerns to the Division of Student
Affairs using an online form located at
https://studentaffairs.indiana.edu/dean-students/student-concern/index.shtml.

**Students needing additional financial or other assistance.**

The Student Advocates Office (SAO) can help students work through
personal and academic problems as well as financial difficulties and
concerns. SAO also assists students working through grade appeals and
withdrawals from all classes. SAO also has emergency funds for IU
students experiencing emergency financial crisis
https://studentaffairs.indiana.edu/student- advocates/.

**Disruptive Students.**

If instructors are confronted by threatening behaviors from students
their first obligation is to insure the immediate safety of the
classroom. When in doubt, call IU Police at 9-911 from any campus
phone or call (812) 855-4111 from off-campus for immediate or
emergency situations. You may also contact the Dean of Students Office
at (812) 855-8188. For additional guidance in dealing with difficult
student situations:
https://ufc.iu.edu/doc/policies/disruptive-students.pdf.

**Academic Misconduct.**

If you suspect that a student has cheated, plagiarized or otherwise committed academic misconduct, refer to the Code of Student Rights, Responsibilities and Conduct:
http://studentcode.iu.edu/.

**Sexual Misconduct.**

As your instructor, one of my responsibilities is to create a positive
learning environment for all students. Title IX and IU’s Sexual
Misconduct Policy prohibit sexual misconduct in any form, including
sexual harassment, sexual assault, stalking, and dating and domestic
violence. If you have experienced sexual misconduct, or know someone
who has, the University can help.

If you are seeking help and would like to speak to someone
confidentially, you can make an appointment with:

* The Sexual Assault Crisis Services (SACS) at (812) 855-8900
  (counseling services)

* Confidential Victim Advocates (CVA) at (812) 856-2469 (advocacy and
  advice services)

* IU Health Center at (812) 855-4011 (health and medical services)

It is also important that you know that Title IX and University policy
require me to share any information brought to my attention about
potential sexual misconduct, with the campus Deputy Title IX
Coordinator or IU’s Title IX Coordinator. In that event, those
individuals will work to ensure that appropriate measures are taken
and resources are made available. Protecting student privacy is of
utmost concern, and information will only be shared with those that
need to know to ensure the University can respond and assist.  I
encourage you to visit
stopsexualviolence.iu.edu to learn more.
