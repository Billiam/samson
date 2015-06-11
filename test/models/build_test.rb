require_relative '../test_helper'

describe Build do
  include GitRepoTestHelper

  let(:project) { Project.new(id: 99999, name: 'test_project', repository_url: repo_temp_dir) }
  let(:sha_digest) { 'cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf' }

  def valid_build(attributes = {})
    Build.new(attributes.reverse_merge(project: project, git_ref: 'master'))
  end

  describe 'validations' do
    let(:repository) { project.repository }
    let(:cached_repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }
    let(:git_tag) { 'test_tag' }

    before do
      create_repo_with_tags(git_tag)
    end

    after do
      FileUtils.rm_rf(repo_temp_dir)
      FileUtils.rm_rf(repository.repo_cache_dir)
      FileUtils.rm_rf(cached_repo_dir)
    end

    it 'should validate git sha' do
      Dir.chdir(repo_temp_dir) do
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit))
        refute_valid(valid_build(git_ref: nil, git_sha: '0123456789012345678901234567890123456789'))
        refute_valid(valid_build(git_ref: nil, git_sha: 'This is a string of 40 characters.......'))
        refute_valid(valid_build(git_ref: nil, git_sha: 'abc'))
      end
    end

    it 'should validate container sha' do
      assert_valid(valid_build(docker_image_id: sha_digest))
      refute_valid(valid_build(docker_image_id: 'This is a string of 64 characters...............................'))
      refute_valid(valid_build(docker_image_id: 'abc'))
    end

    it 'should validate git_ref' do
      assert_valid(valid_build(git_ref: 'master'))
      assert_valid(valid_build(git_ref: git_tag))
      refute_valid(Build.new(project: project))
      Dir.chdir(repo_temp_dir) do
        assert_valid(valid_build(git_ref: current_commit))
      end
      refute_valid(valid_build(git_ref: 'some_tag_i_made_up'))
    end
  end

  describe 'successful?' do
    let(:build) { builds(:staging) }

    it 'returns true when all successful' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::SUCCESSFUL)
      assert build.successful?
    end

    it 'returns false when there is a failure' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::FAILED)
      refute build.successful?
    end

    it 'returns false when there is a pending status' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::PENDING)
      refute build.successful?
    end
  end

  describe '#update_docker_image_attributes' do
    let(:build) { valid_build }

    it 'sets the expected attributes' do
      build.update_docker_image_attributes(digest: sha_digest, tag: 'v123')
      assert_equal(sha_digest, build.docker_image_id)
      assert_equal('v123', build.docker_ref)
      assert_match(/[a-z.-]+\/#{project.name}@sha256:#{sha_digest}/, build.docker_repo_digest)
    end

    it 'defaults ref to the label' do
      build.label = 'Created by Jon'
      build.update_docker_image_attributes(digest: sha_digest)
      assert_equal('created-by-jon', build.docker_ref)
    end

    it 'defaults ref to "latest" if no label' do
      build.label = nil
      build.update_docker_image_attributes(digest: sha_digest)
      assert_equal('latest', build.docker_ref)
    end
  end
end
