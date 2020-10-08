all="$head,$compute"

alias on-all="pdsh -w $all"
alias on-head="pdsh -w $head"
alias on-compute="pdsh -w $compute"
alias on-build="pdsh -w $build"

alias cp-all="pdcp -w $all"
alias cp-head="pdcp -w $head"
alias cp-compute="pdcp -w $compute"
alias cp-build="pdcp -w $build"
