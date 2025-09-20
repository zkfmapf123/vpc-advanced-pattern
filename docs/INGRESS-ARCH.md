## ingress vpc architecture

![tgw](../public/tgw.png)

## Concept

- ingress vpc (all traffics - inbound & outbound)
- blue vpc (service vpc)
- green vpc (service vpc)

## Todo

- vpc flow logs 
- transit gateway

## VPC Route Table

### ingress vpc rt

![ingress private rt](../public/ingress-private-rt.png)
![ingress public rt](../public/ingress-public-rt.png)

## TGW Route Table

- 각 Connection 당 Route Table 이 존재해야 함

![tgw rt](../public/tgw-rt.png)

