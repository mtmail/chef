#
# Cookbook:: ssl
# Resource:: ssl_certificate
#
# Copyright:: 2017, OpenStreetMap Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default_action :create

property :certificate, String, :name_property => true
property :domains, [String, Array], :required => true

action :create do
  node.default[:letsencrypt][:certificates][new_resource.certificate] = {
    :domains => Array(new_resource.domains)
  }

  if letsencrypt
    certificate = letsencrypt["certificate"]
    key = letsencrypt["key"]
  end

  if certificate
    file "/etc/ssl/certs/#{new_resource.certificate}.pem" do
      owner "root"
      group "root"
      mode 0o444
      content certificate
      backup false
      manage_symlink_source false
      force_unlink true
    end

    file "/etc/ssl/private/#{new_resource.certificate}.key" do
      owner "root"
      group "ssl-cert"
      mode 0o440
      content key
      backup false
      manage_symlink_source false
      force_unlink true
    end
  else
    alt_names = new_resource.domains.collect { |domain| "DNS:#{domain}" }

    openssl_x509_certificate "/etc/ssl/certs/#{new_resource.certificate}.pem" do
      key_file "/etc/ssl/private/#{new_resource.certificate}.key"
      owner "root"
      group "ssl-cert"
      mode 0o640
      org "OpenStreetMap"
      email "operations@osmfoundation.org"
      common_name new_resource.domains.first
      subject_alt_name alt_names
      extensions "keyUsage" => { "values" => %w[digitalSignature keyEncipherment], "critical" => true },
                 "extendedKeyUsage" => { "values" => %w[serverAuth clientAuth], "critical" => true }
    end
  end
end

action :delete do
  file "/etc/ssl/certs/#{new_resource.certificate}.pem" do
    action :delete
  end

  file "/etc/ssl/private/#{new_resource.certificate}.key" do
    action :delete
  end
end

action_class do
  def letsencrypt
    @letsencrypt ||= search(:letsencrypt, "id:#{new_resource.certificate}").first
  end
end
