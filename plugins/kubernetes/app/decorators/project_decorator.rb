Project.class_eval do
  has_many :kubernetes_releases, class_name: 'Kubernetes::Release'
  has_many :roles, class_name: 'Kubernetes::Role'

  def file_from_repo(path, git_ref)
    repository.file_content path, git_ref
  end

  def kubernetes_config_files_in_repo(git_ref)
    path = 'kubernetes'
    return [] unless files = repository.file_content(path, git_ref)
    files.split("\n").grep(/\.(yml|yaml|json)$/).map { |f| "#{path}/#{f}" }
  end

  # Imports the new kubernetes roles. This operation is atomic: if one role fails to be imported, none
  # of them will be persisted and the soft deletion will be rollbacked.
  def refresh_kubernetes_roles!(git_ref)
    config_files = kubernetes_config_files_in_repo(git_ref)
    return if config_files.to_a.empty?

    Project.transaction do
      roles.each(&:soft_delete!)

      kubernetes_config_files(config_files, git_ref) do |config_file|
        roles.create!(
          config_file: config_file.file_path,
          name: config_file.deployment.metadata.labels.role,
          service_name: config_file.service.metadata.name,
          ram: config_file.deployment.ram_mi,
          cpu: config_file.deployment.cpu_m,
          replicas: config_file.deployment.spec.replicas,
          deploy_strategy: config_file.deployment.strategy_type
        )
      end

      # Need to reload the project to refresh the association otherwise
      # the soft deleted roles will be rendered by the JSON serializer
      reload.roles.not_deleted
    end
  end

  def name_for_label
    name.parameterize('-')
  end

  private

  # Given a list of kubernetes configuration files, retrieves the corresponding contents
  # and builds the corresponding Kubernetes Roles
  def kubernetes_config_files(config_files, git_ref)
    config_files.map do |file|
      file_contents = file_from_repo(file, git_ref)
      config_file = Kubernetes::RoleConfigFile.new(file_contents, file)
      yield config_file if block_given?
    end
  end
end
