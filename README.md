# Masterthesis Tom Kleinhapl

Thesis PDF: https://github.com/tiemtom/ma-kleinhapl-tom/blob/main/MA-Kleinhapl-Tom.pdf

This repository hosts the thesis along with the code and scripts developed in the accompanying project.

Thesis abstract:

This thesis examines the current multi cloud market, specifically regarding multi cloud application deployment and portability. The standardisation of cloud technologies and the combination of technology advancements made with infrastructure as code, microservices and multi cloud should make it possible for end users to leverage advantages of multi cloud within a single application. The central research question this thesis aims to answer is: Can single applications be hosted on a multi cloud architecture using a high degree of automation (deployment and configuration) in an economical and feasible way in the current cloud infrastructure landscape?

To achieve this, a practical example is implemented and used to demonstrate the current effort, problems and difficulties encountered when developing a flexible deployment model using multiple cloud providers. The practical implementation revolves around a microservice application, that was conceived specifically for the Azure cloud, which is converted into a multi cloud capable architecture for Azure and AWS. Using the IAC tool Terraform, multiple deployment plans are constructed, each using a different configuration. These deployment plans can be deployed interchangeably with minimal to no changes to the application code.

As such, the research question can be affirmed. However, the effort to design and implement multi cloud capable applications is still very high, in part due to a lack of standard adoption in the cloud. Not only the deployment of services to the cloud lacks standardisation, also storage interfaces are mostly proprietary in the cloud. This extends the challenge of creating multi cloud applications from  the deployment plans to the application code, which needs to be able to interface with multiple standards. Still, using third party abstraction tools, building provider-agnostic applications is possible. Whether such a setup is needed and beneficial can only be evaluated on a case to case basis.

Portability between providers out of the box is still a long way away and unlikely to be available in the near future. This thesis conceives three main paths through which infrastructure portability in the cloud can be achieved. These are custom in-house solutions, portability through cloud brokers and finally the enforcement of standardised interfaces through policy. However, given the current cloud infrastructure market, which is dominated by a few big players, it is difficult to envisage an organic development towards a more open or broker driven market.


**For deployment instructions see the README in the code directory.**
