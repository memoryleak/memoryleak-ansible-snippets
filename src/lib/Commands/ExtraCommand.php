<?php


namespace AnsibleSnippetGenerator\Commands;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Twig\Environment;
use Twig\Loader\FilesystemLoader;
use Twig\TwigFunction;

class ExtraCommand extends Command
{
    private FilesystemLoader $loader;
    private Environment $twig;

    private string $baseDir;

    public function __construct(string $baseDir)
    {
        $this->baseDir = $baseDir;
        $this->loader = new FilesystemLoader($this->baseDir . DIRECTORY_SEPARATOR . 'templates');
        $this->twig = new Environment($this->loader, [
            'cache' => false,
            'autoescape' => false
        ]);

        parent::__construct('generate:extra');
    }

    protected function configure()
    {
        $this
            ->setDescription('Generate snippets from extras ')
            ->setHelp('This command allows you to generate snippets')
            ->addArgument('template', InputArgument::REQUIRED, "Twig template to use")
            ->addArgument('input', InputArgument::REQUIRED, "Path to file to be used as input")
            ->addArgument('output', InputArgument::REQUIRED, 'Path to file for the snippet to be saved in');

        parent::configure();
    }

    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $template = $this->twig->load($input->getArgument('template'));

        if (!file_exists($input->getArgument('input')) || !is_readable($input->getArgument('input'))) {
            $output->writeln('<error>Source file not readable</error>: ' . $input->getArgument('input'));
            return Command::FAILURE;
        }

        $extraSnippet = file_get_contents($input->getArgument('input'));
        $extraName = explode('.', basename($input->getArgument('input')))[0];
        $extra = [
            'name' => $extraName,
            'description' => $extraName . ' snippet',
            'content' => $extraSnippet
        ];

        $snippetContent = $template->render(['extra' => $extra]);
        file_put_contents($input->getArgument('output'), $snippetContent);

        return Command::SUCCESS;
    }

}