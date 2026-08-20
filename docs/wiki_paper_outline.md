# TA Wiki Paper Outline 

## 1. Introduction
- Main problem: TA support in academic departments is often ad hoc and fragmented 
	- Knowledge circulates through informal channels, very inefficient
- What we did: built a collaboratively maintained wiki hosted on GitHub as a centralized TA resource platform
- Why GitHub? Applies open-source principles (version control, transparency, community ownership) to teaching support
- Main findings with our department: the wiki is universally seen as valuable, but actual usage and contribution falls behind that endorsement
- Purpose of paper: documents the design and implementation (of the WIKI, not the survey), evaluates it through a 12-respondent survey, and discusses what it would take to close the gap between the value and adoption

## 2. Background & Related Work
- How departments typically support TAs (orientations, handbooks, peer mentorship, informal channels)
- Recent literature on sustainable TA professional development structures beyond one-time training (Sadera et al., 2024; Freeman et al., 2026)
- Collaborative knowledge management in academic settings
- Wikis as educational tools
- GitHub beyond software: its use in education, open science, open courseware
- GitHub wikis specifically: commit-based history, distributed editing, documentation features (GitHub Docs, 2026a, 2026b) = reinforces the importance of documenting a process, in the same way that's done with code. The analogy here is seeing TA work as writing software, then the Wiki is the documentation on HOW to do TA work, in a similar way that's used to document HOW to write code when writing software.
- A departmental TA resource wikis appear uncommon (maybe novel need to look into this)

## 3. The TA Wiki: Design & Implementation
- Motivation: why the department needed a centralizedresource (even when the department is really small)
- Why GitHub? Design decisions and tradeoffs
  - Version control: track changes, accountability, full history
  - Modularity: organize by course, topic, or role
  - Customizability: markdown, flexible structure
  - Transparency: anyone can see edits and who made them
  - Known tradeoff: technical barrier for non-Git users
  - More streamlined compared to other platforms such as Google docs
- Wiki contains course specific advice, reusable teaching materials, recurring procedures, links to departmental/university resources, etc.
- Maintained through PRs and direct edits who contributes
-  Made an organized attempt to boost engagement
  - Very Low participation which motivates the survey study

## 4. Study Design

Antonio's doc describes the results well, but is lacking an explanation of how the questionnaire was designed and how the subjects were approached. 

**Descriptive research questions:**

1. **Awareness and access:** What is the overall level of awareness of the TA Wiki among graduate students, and how are they finding out about it (or not)?
2. **Usage and value:** Are graduate students finding the TA Wiki helpful, and where does it fit (or not fit) within the broader landscape of resources TAs currently rely on?
3. **Platform and accessibility:** What are the benefits of hosting the wiki on GitHub, and how does comfort with GitHub relate to wiki usage and contribution?
4. **Engagement and contribution:** What are the main barriers to contributing to the wiki?
	 skills, motivation, confidence, etc 
	 how effective was the editathon as a form of outreach?
5. **Future directions:** What would an ideal TA resource look like to graduate students, and how close is the current wiki to that vision?

## 5. Results
### 5.1 Respondent Context
- 9/12 had 5+ TA quarters, 9/12 at least moderate Git comfort, 10/12 at least moderate teaching interest
- Relatively experienced, technically comfortable group — important caveat for interpreting results

### 5.2 Current Resource Landscape
- Only 4/12 selected the wiki as a current teaching-support resource
- Peer advice, instructor/faculty advice, and online resources were selected more often
- The wiki needs to coexist with and supplement these existing channels, not replace them

### 5.3 Awareness, Visitation, and Consultation
- 12/12 had at least some awareness
- 9/12 had visited at least once
- But among 9 valid consultation responses: 4 never, 2 rarely, 3 sometimes
- High awareness does not translate to regular use

### 5.4 Perceived Value (the gap)
- 12/12 agreed the wiki is or could be valuable
- 8/12 would recommend it
- 11/12 support continued maintenance
- Universal value endorsement vs. low actual usage is the central finding

### 5.5 Contribution
- 5 yes, 4 no, 3 missing (possible range: 5-8 contributors)
- 8/12 understand how to contribute, but only 5/12 agree the process is straightforward
- 8/12 say a simpler interface would increase willingness
- 6/12 say training or a walkthrough would help
- Understanding ≠ finding it easy

### 5.6 GitHub as a Platform
- Willingness to use: 5/12 no difference, 4/12 more likely, 3/12 less likely
- Willingness to contribute: 6/12 no difference, 3/12 more likely, 3/12 less likely
- Advantages selected: version control, transparency
- Disadvantages selected: steep learning curve, technical setup, overly formal contribution process
- Mixed rather than uniformly positive or negative

### 5.7 Editathon
- 12/12 had heard of it, only 4/12 participated
- Awareness was not the problem — motivation and accessibility were

### 5.8 Open-Text Themes
- Reasons and spaces for contributing (6 records)
- Course-specific and current materials (5)
- Human support and instructional coordination (5)
- Value tied to concrete use (5)
- Visibility and demonstrated usefulness (4)
- Platform friction and navigation (3)
- Maintenance responsibility and content currency (2)



## 6. Discussion

### 6.1 Gap between value and adoption
- Students seem to generally think its valuable, but it's not part of ordinary TA work
- Central challenge is going from merely adoption to approval

### 6.2 Github Consisderations
- Version control and transparency and real advantages, but the learning curve and more formal workflows present barriers, even among a sample of students who are relatively comfortable with Git
- How can we maintain these benefits while reducing the entry cost?
  - If adoption is low even among those experienced with git, what about those who are less experienced?
  - Motivate needs for reducing friction somehow (add specific ways to contribute on the wiki page/allow direct uploads?)

### Content and Maintenance as Platform Design Questions
- Course-sepcific tips, rubrics, templates, and current materials are what TA's want
- Maintenance responsibility needs to be defined 
  
## Editathon
- Widespread awareness but low participation
- Awareness not the issue, and results suggest formating, timing, and percieved value of contributing was te issue

## Potential
- What this model could look like if we address barriers
- Possible recommendations for department: lower friction for participation, strengthen course-specific content, making usefulness visible, and define maintenance



## 7. Limitations

Department size
Comments on repeated text from other webpages - need to "clean" the wiki as it is now, to avoid double work. 
Other departments have made wikis (Physics, UCSC) however, they are not open for contributions from the students and don't include repositories for the class materials. 


## 8. Conclusion
- Promising proof of concept and novel approach, valued, but not adopted as a regular resource
- Gap between adoption is the key finding and chalenge
- Next steps: make it easier to contribute, strengthen and add course speciifc content, make the usefulneess visible, define maintenance, and someow measure whether those changes increase use
- Open-source platforms like githu have potential to support taching, but the platform design has to meet the users where they are at


## Misc Notes
- In paper, provide background to how Github works so reader can have more of a grounded understanding for the barriers
- Describe how TA's can contribute (either through uploading materials/resources/tools directly through the repo as a PR, or updating the wiki page for content)
- 

