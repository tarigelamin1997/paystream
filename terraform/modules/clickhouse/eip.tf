# Cross-Audit Finding 4 Resolution:
# The original plan placed an Elastic IP on the ClickHouse EC2 instance.
# However, ClickHouse is in a private subnet — EIPs cannot be attached
# to private subnet instances for direct public access.
#
# Resolution: The Elastic IP is attached to the bastion host (public subnet).
# ClickHouse is accessed via SSH tunneling through the bastion.
# See: terraform/modules/bastion/main.tf for the EIP resource.
#
# This file is intentionally empty per the cross-audit correction.
