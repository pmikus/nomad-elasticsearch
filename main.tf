provider "nomad" {
  address = "http://nomad.mycompany.com:4646"
  region  = "yul1"
  alias   = "lf"
}

resource "nomad_job" "monitor" {
  provider = nomad.lf
  jobspec  = file("${path.module}/es-cluster.nomad")
}
